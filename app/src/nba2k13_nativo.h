// nba2k13 - native renderer, phase 1: the sink owner.
//
// The emulation path costs about 260 us per GPU operation on this console (659 draws + 876 render
// target transfers + 19 resolves per frame, measured at 2 fps). The NFS MW port hit the same wall and
// replaced the emulation with a renderer that reads the game's own PM4 ring and issues Vulkan
// directly - 1.5-1.8 us per draw - and that is the only way 30 fps happens here.
//
// This file owns the other end of rex::graphics::native_sink: it receives one record per completed
// frame and answers the two questions phase 1 exists to answer:
//
//   1. Is the capture complete? Every draw the game puts in the ring must arrive here, either as a
//      draw, as one the backend refused, or as one a visibility query killed. Anything unaccounted for
//      is a gap a native renderer would render wrong.
//   2. What is the real pipeline set? Distinct (vertex shader, pixel shader, pipeline key) triples.
//      Phase 3 precompiles exactly that list at startup, which is what keeps special moves and menu
//      transitions from stalling on a shader compile.
//
// Nothing here draws anything and nothing here changes what the emulation does. Turning it off is
// deleting the file it reads.

#pragma once

namespace nba2k13::nativo {

// Reads nativo.txt, and if it is not "0" starts collecting. Must be called before the GPU threads
// exist (OnPostSetup), because the sink is not internally synchronised.
void Iniciar();

// Stops collecting and writes whatever is pending.
void Detener();

}  // namespace nba2k13::nativo
