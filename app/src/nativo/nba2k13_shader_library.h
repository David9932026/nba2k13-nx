#pragma once

#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <mutex>
#include <span>
#include <vector>

namespace nba2k13::natsh {

class BibliotecaShaders;

// The original container also identifies constants and interface. The physical
// code alone is not enough. It is looked up before the driver creates its object.
struct Shader {
  std::vector<uint8_t> original;  // emptied after the load (SoltarOriginales) to save memory
  std::vector<uint32_t> spirv;    // version 1 / packer: in memory. Version 2: empty, see Spirv()
  uint64_t huella = 0;
  bool vertices = false;
  // PATCH(cola) N2e: version 2 packages (the full 7338-container library is 242 MB of SPIR-V,
  // far more than the Switch has free) keep only the index in memory and read each SPIR-V from
  // the file when a pipeline needs it.
  uint32_t tam_original = 0;
  uint32_t spirv_palabras = 0;
  uint64_t spirv_offset = 0;
  bool info_previa = false;  // kills / sombra_minimo come from the package
  uint32_t kills = 0;
  bool sombra_minimo = false;
  const BibliotecaShaders* biblioteca = nullptr;

  // The SPIR-V words (a copy). Empty if it cannot be read.
  std::vector<uint32_t> Spirv() const;
};

class BibliotecaShaders {
 public:
  BibliotecaShaders() = default;
  ~BibliotecaShaders();
  BibliotecaShaders(const BibliotecaShaders&) = delete;
  BibliotecaShaders& operator=(const BibliotecaShaders&) = delete;

  // Transactional load: an invalid file does not replace the library.
  // Pointers returned by Buscar last until the next successful load.
  void Cargar(std::span<const uint8_t> archivo);
  void Cargar(const std::filesystem::path& archivo);
  const Shader* Buscar(std::span<const uint8_t> original) const;
  const std::vector<Shader>& shaders() const { return shaders_; }
  // Frees the original containers once they have been parsed. Buscar then compares
  // fingerprint and length only.
  void SoltarOriginales();
  bool perezosa() const { return archivo_ != nullptr; }

  std::vector<uint32_t> LeerSpirv(const Shader& s) const;

 private:
  void CargarV2(const std::filesystem::path& ruta);
  std::vector<Shader> shaders_;
  std::FILE* archivo_ = nullptr;
  mutable std::mutex mutex_;
};

// Versioned local format, little-endian, with integrity checks.
// It contains private data derived from the game; it is not embedded in the executable.
std::vector<uint8_t> EmpaquetarShaders(std::vector<Shader> shaders);
// Version 2 (lazy SPIR-V), written straight to a file. Returns the number of entries.
size_t EmpaquetarShadersV2(std::vector<Shader> shaders, const std::filesystem::path& salida);

}  // namespace nba2k13::natsh
