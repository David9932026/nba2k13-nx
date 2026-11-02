/**
 ******************************************************************************
 * Xenia : Xbox 360 Emulator Research Project                                 *
 ******************************************************************************
 * Copyright 2020 Ben Vanik. All rights reserved.                             *
 * Released under the BSD license - see LICENSE in the root for more details. *
 ******************************************************************************
 *
 * @modified    Tom Clay, 2026 - Adapted for ReXGlue runtime
 */

#include <rex/filesystem/vfs.h>
#include <rex/logging.h>
#include <rex/string.h>

#include <rex/filesystem/devices/host_path_entry.h>

REXCVAR_DEFINE_BOOL(allow_game_relative_writes, false, "Filesystem",
                    "Not useful to non-developers. Allows code to write to paths "
                    "relative to game://. Used for "
                    "generating test data to compare with original hardware.");

namespace rex::filesystem {

VirtualFileSystem::VirtualFileSystem() {}

VirtualFileSystem::~VirtualFileSystem() {
  // Delete all devices.
  // This will explode if anyone is still using data from them.
  devices_.clear();
  symlinks_.clear();
}

bool VirtualFileSystem::RegisterDevice(std::unique_ptr<Device> device) {
  auto global_lock = global_critical_region_.Acquire();
  devices_.emplace_back(std::move(device));
  return true;
}

bool VirtualFileSystem::UnregisterDevice(const std::string_view path) {
  auto global_lock = global_critical_region_.Acquire();
  for (auto it = devices_.begin(); it != devices_.end(); ++it) {
    if ((*it)->mount_path() == path) {
      REXFS_DEBUG("Unregistered device: {}", (*it)->mount_path());
      devices_.erase(it);
      return true;
    }
  }
  return false;
}

bool VirtualFileSystem::RegisterSymbolicLink(const std::string_view path,
                                             const std::string_view target) {
  auto global_lock = global_critical_region_.Acquire();
  symlinks_.insert({std::string(path), std::string(target)});
  REXFS_DEBUG("Registered symbolic link: {} => {}", path, target);

  return true;
}

bool VirtualFileSystem::UnregisterSymbolicLink(const std::string_view path) {
  auto global_lock = global_critical_region_.Acquire();
  auto it = std::find_if(symlinks_.cbegin(), symlinks_.cend(), [&](const auto& s) {
    return rex::string::utf8_equal_case(path, s.first);
  });
  if (it == symlinks_.end()) {
    return false;
  }
  REXFS_DEBUG("Unregistered symbolic link: {} => {}", it->first, it->second);

  symlinks_.erase(it);
  return true;
}

bool VirtualFileSystem::FindSymbolicLink(const std::string_view path, std::string& target) {
  auto it = std::find_if(symlinks_.cbegin(), symlinks_.cend(), [&](const auto& s) {
    return rex::string::utf8_starts_with_case(path, s.first);
  });
  if (it == symlinks_.cend()) {
    return false;
  }
  target = (*it).second;
  return true;
}

bool VirtualFileSystem::ResolveSymbolicLink(const std::string_view path, std::string& result) {
  result = path;
  bool was_resolved = false;
  while (true) {
    auto it = std::find_if(symlinks_.cbegin(), symlinks_.cend(), [&](const auto& s) {
      return rex::string::utf8_starts_with_case(result, s.first);
    });
    if (it == symlinks_.cend()) {
      break;
    }
    // Found symlink!
    auto target_path = (*it).second;
    auto relative_path = result.substr((*it).first.size());
    result = target_path + relative_path;
    was_resolved = true;
  }
  return was_resolved;
}

Entry* VirtualFileSystem::ResolvePath(const std::string_view path) {
  auto global_lock = global_critical_region_.Acquire();

  // Resolve relative paths
  auto normalized_path(rex::string::utf8_canonicalize_guest_path(path));

  // Resolve symlinks.
  std::string resolved_path;
  bool had_symlink = ResolveSymbolicLink(normalized_path, resolved_path);
  if (had_symlink) {
    normalized_path = resolved_path;
  }

  // Find the device.
  auto it = std::find_if(devices_.cbegin(), devices_.cend(), [&](const auto& d) {
    return rex::string::utf8_starts_with_case(normalized_path, d->mount_path());
  });
  if (it == devices_.cend()) {
    REXFS_WARN("VFS: '{}' -> [no device]", path);
    // Supress logging the error for ShaderDumpxe:\CompareBackEnds as this is
    // not an actual problem nor something we care about.
    if (path != "ShaderDumpxe:\\CompareBackEnds") {
      REXFS_ERROR("ResolvePath({}) failed - device not found", path);
    }
    return nullptr;
  }

  const auto& device = *it;
  auto relative_path = normalized_path.substr(device->mount_path().size());
  auto* entry = device->ResolvePath(relative_path);

  if (entry) {
    if (had_symlink) {
      REXFS_TRACE("VFS resolved '{}' via symlink '{}' on device '{}' -> '{}'", path,
                  normalized_path, device->mount_path(), entry->absolute_path());
    } else {
      REXFS_TRACE("VFS resolved '{}' on device '{}' -> '{}'", path, device->mount_path(),
                  entry->absolute_path());
    }
  } else {
    if (had_symlink) {
      REXFS_DEBUG("VFS: entry not found for '{}' (via symlink '{}') on device '{}'", path,
                  normalized_path, device->mount_path());
    } else {
      REXFS_DEBUG("VFS: entry not found for '{}' on device '{}'", path, device->mount_path());
    }
  }

  return entry;
}

Entry* VirtualFileSystem::CreatePath(const std::string_view path, uint32_t attributes) {
  // Create all required directories recursively.
  auto path_parts = rex::string::utf8_split_path(path);
  if (path_parts.empty()) {
    return nullptr;
  }
  auto partial_path = std::string(path_parts[0]);
  auto partial_entry = ResolvePath(partial_path);
  if (!partial_entry) {
    return nullptr;
  }
  auto parent_entry = partial_entry;
  for (size_t i = 1; i < path_parts.size() - 1; ++i) {
    partial_path = rex::string::utf8_join_guest_paths(partial_path, path_parts[i]);
    auto child_entry = ResolvePath(partial_path);
    if (!child_entry) {
      child_entry = parent_entry->CreateEntry(path_parts[i], kFileAttributeDirectory);
    }
    if (!child_entry) {
      return nullptr;
    }
    parent_entry = child_entry;
  }
  return parent_entry->CreateEntry(path_parts[path_parts.size() - 1], attributes);
}

bool VirtualFileSystem::DeletePath(const std::string_view path) {
  auto entry = ResolvePath(path);
  if (!entry) {
    return false;
  }
  auto parent = entry->parent();
  if (!parent) {
    // Can't delete root.
    return false;
  }
  return parent->Delete(entry);
}

X_STATUS VirtualFileSystem::OpenFile(Entry* root_entry, std::string_view path,
                                     FileDisposition creation_disposition, uint32_t desired_access,
                                     bool is_directory, bool is_non_directory, File** out_file,
                                     FileAction* out_action) {
  // TODO(gibbed): should 'is_directory' remain as a bool or should it be
  // flipped to a generic FileAttributeFlags?

  // PATCH(cola): probe. If this never prints while NtCreateFile keeps failing on
  // paths that contain a colon, the failing open is not coming through here at all.
  if (path.find(':', 2) != std::string_view::npos) {
    REXFS_ERROR("OpenFile sees colon path: '{}' disp={} dir={}", std::string(path),
                uint32_t(creation_disposition), is_directory);
  }

  // PATCH(cola): the title addresses its content cache with an extra "CONTENT:" segment
  // inside the path, e.g. "cdn:\CONTENT:0B\4A\<guid>". A colon is not a legal file name
  // character on the host, so every such open fails with "not found" and the cache looks
  // empty even though the title just wrote it. Drop that segment so the read lands on the
  // file that was written without the prefix. Only segments after the device are touched.
  std::string patched_path_storage;
  {
    bool has_inner_colon = false;
    for (size_t i = 2; i < path.size(); ++i) {
      if (path[i] == ':') {
        has_inner_colon = true;
        break;
      }
    }
    if (has_inner_colon) {
      static int s_colon_logs = 0;
      const bool log_this = ++s_colon_logs <= 60;
      patched_path_storage.reserve(path.size());
      size_t seg_start = 0;
      bool first_segment = true;
      for (size_t i = 0; i <= path.size(); ++i) {
        if (i == path.size() || path[i] == '\\' || path[i] == '/') {
          const auto segment = path.substr(seg_start, i - seg_start);
          // PATCH(cola): the extra segment is glued to the following one, e.g.
          // "cdn:\CONTENT:0B\4A\<guid>" splits into "cdn:" / "CONTENT:0B" / "4A" / "<guid>",
          // so drop everything up to and including the colon instead of the whole segment.
          std::string_view kept = segment;
          if (!first_segment) {
            const size_t colon = segment.find(':');
            if (colon != std::string_view::npos) {
              kept = segment.substr(colon + 1);
            }
          }
          const bool drop = !first_segment && kept.empty();
          if (!drop) {
            if (!first_segment) {
              patched_path_storage.push_back('\\');
            }
            patched_path_storage.append(kept);
          }
          first_segment = false;
          seg_start = i + 1;
        }
      }
      if (log_this) {
        REXFS_ERROR("colon-rebuild in='{}' out='{}'", std::string(path),
                    patched_path_storage);
      }
      if (!patched_path_storage.empty() && patched_path_storage != path) {
        path = patched_path_storage;
      }
    }
  }

  // PATCH(cola): the title opens the content root itself as a file - path is exactly
  // "save:\", FILE_NON_DIRECTORY_FILE is set and the disposition is OVERWRITE_IF - and it
  // retries it 32 times before giving up on a black screen. Under XAM the data of a content
  // lives in a file named after the content, which is exactly how every save this title
  // writes looks on disk (cdn.CHE/cdn.CHE, User.USR/User.USR, ...), so map that root open
  // onto "<root>/<name of the root>". Only for a non-directory request: opening the root as
  // a directory has to keep working, it is how the content gets mounted.
  std::string root_file_storage;
  if (is_non_directory && !is_directory) {
    std::string_view trimmed = path;
    while (!trimmed.empty() && (trimmed.back() == '\\' || trimmed.back() == '/')) {
      trimmed.remove_suffix(1);
    }
    if (!trimmed.empty() && trimmed.back() == ':') {
      std::string root_path(trimmed);
      root_path.push_back('\\');
      Entry* root = !root_entry ? ResolvePath(root_path) : root_entry->ResolvePath(root_path);
      if (root && (root->attributes() & kFileAttributeDirectory)) {
        const auto* host_root = dynamic_cast<const HostPathEntry*>(root);
        if (host_root && !host_root->host_path().empty()) {
          const std::string self_name = rex::path_to_utf8(host_root->host_path().filename());
          if (!self_name.empty()) {
            root_file_storage = std::string(trimmed) + "\\" + self_name;
            REXFS_WARN("content-root open '{}' mapped onto '{}'", std::string(path),
                       root_file_storage);
            path = root_file_storage;
          }
        }
      }
    }
  }

  // Cleanup access.
  if (desired_access & FileAccess::kGenericRead) {
    desired_access |= FileAccess::kFileReadData;
  }
  if (desired_access & FileAccess::kGenericWrite) {
    desired_access |= FileAccess::kFileWriteData;
  }
  if (desired_access & FileAccess::kGenericAll) {
    desired_access |= FileAccess::kFileReadData | FileAccess::kFileWriteData;
  }

  // Lookup host device/parent path.
  // If no device or parent, fail.
  Entry* parent_entry = nullptr;
  Entry* entry = nullptr;

  auto base_path = rex::string::utf8_find_base_guest_path(path);
  if (!base_path.empty()) {
    parent_entry = !root_entry ? ResolvePath(base_path) : root_entry->ResolvePath(base_path);
    if (!parent_entry) {
      *out_action = FileAction::kDoesNotExist;
      return X_STATUS_NO_SUCH_FILE;
    }

    auto file_name = rex::string::utf8_find_name_from_guest_path(path);
    entry = parent_entry->GetChild(file_name);
  } else {
    entry = !root_entry ? ResolvePath(path) : root_entry->GetChild(path);
  }

  if (entry) {
    if (entry->attributes() & kFileAttributeDirectory && is_non_directory) {
      return X_STATUS_FILE_IS_A_DIRECTORY;
    }

    /*
     * If the cached entry does not exist on host anymore, invalidate it.
     *
     * Only on writable devices. This was a stat to the SD on every successful open, and on a
     * read-only device (the game data) it can never say no: the file was there at mount time and
     * nobody deletes it during play. On writable devices (saves and profiles) it is needed, because
     * the game itself deletes and recreates files and the in-memory entry goes stale; that case is
     * unchanged.
     */
    if (parent_entry && !parent_entry->is_read_only()) {
      const auto* host_path_entry = dynamic_cast<const HostPathEntry*>(parent_entry);
      if (host_path_entry) {
        const auto file_path = host_path_entry->host_path() / rex::to_path(entry->name());
        if (!std::filesystem::exists(file_path)) {
          entry->Delete();
          entry = nullptr;
        }
      }
    }
  }

  // Check if exists (if we need it to), or that it doesn't (if it shouldn't).
  switch (creation_disposition) {
    case FileDisposition::kOpen:
    case FileDisposition::kOverwrite:
      // Must exist.
      if (!entry) {
        *out_action = FileAction::kDoesNotExist;
        return X_STATUS_NO_SUCH_FILE;
      }
      break;
    case FileDisposition::kCreate:
      // Must not exist.
      // PATCH(cola): the title creates its cdn:\xx\yy cache directories with FILE_CREATE on every
      // start and, when they already exist from a previous run, treats the collision as a failure
      // and retries 33 times per directory. Treat creating an existing directory as opening it.
      if (entry && is_directory && (entry->attributes() & kFileAttributeDirectory)) {
        REXFS_ERROR("[DIRCREATE] existing directory '{}' opened instead of collision", std::string(path));
        break;
      }
      if (entry) {
        *out_action = FileAction::kExists;
        return X_STATUS_OBJECT_NAME_COLLISION;
      }
      break;
    default:
      // Either way, ok.
      break;
  }

  // Verify permissions.
  bool wants_write =
      desired_access & FileAccess::kFileWriteData || desired_access & FileAccess::kFileAppendData;
  if (wants_write &&
      ((parent_entry && parent_entry->is_read_only()) || (entry && entry->is_read_only()))) {
    // Match Xenia behavior: downgrade to read access instead of failing.
    REXFS_WARN("Attempted to open read-only file/dir for write: {}", path);
    desired_access = FileAccess::kGenericRead | FileAccess::kFileReadData;
  }

  bool created = false;
  if (!entry) {
    // Remember that we are creating this new, instead of replacing.
    created = true;
    *out_action = FileAction::kCreated;
  } else {
    // May need to delete, if it exists.
    switch (creation_disposition) {
      case FileDisposition::kCreate:
        *out_action = FileAction::kOpened;
        break;
      case FileDisposition::kSuperscede:
        // Replace (by delete + recreate).
        if (!entry->Delete()) {
          return X_STATUS_ACCESS_DENIED;
        }
        entry = nullptr;
        *out_action = FileAction::kSuperseded;
        break;
      case FileDisposition::kOpen:
      case FileDisposition::kOpenIf:
        // Normal open.
        *out_action = FileAction::kOpened;
        break;
      case FileDisposition::kOverwrite:
      case FileDisposition::kOverwriteIf:
        // Overwrite by delete + recreate, or truncate if delete fails
        // (host file may be briefly locked by cloud sync, AV, etc.).
        if (entry->Delete()) {
          entry = nullptr;
        } else if (!entry->Truncate()) {
          return X_STATUS_ACCESS_DENIED;
        }
        *out_action = FileAction::kOverwritten;
        break;
    }
  }
  if (!entry) {
    // Create if needed (either new or as a replacement).
    entry = CreatePath(path, !is_directory ? kFileAttributeNormal : kFileAttributeDirectory);
    if (!entry) {
      return X_STATUS_ACCESS_DENIED;
    }
  }

  // Open.
  auto result = entry->Open(desired_access, out_file);
  if (XFAILED(result)) {
    *out_action = FileAction::kDoesNotExist;
  }
  return result;
}

}  // namespace rex::filesystem
