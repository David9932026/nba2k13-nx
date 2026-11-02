// nba2k13 - captures of the game image for the native renderer tests. With
// NBA2K13_captura_cada_s > 0 it saves a PNG every N seconds in capturas/ next
// to the executable, in native and in emulation mode, to compare the two
// without looking at the screen.

#pragma once

#include <cstdint>
#include <functional>

namespace rex::ui {
class Presenter;
}

namespace nba2k13::captura {

// Starts the capture thread if the cvar asks for it. The presenter is requested
// on every capture: it may not exist yet at startup.
void Arrancar(std::function<rex::ui::Presenter*()> obtener_presentador);

// Stops the thread (idempotent).
void Parar();

// PATCH(cola): writes one image as an 8-bit PNG, RGBA in memory (R8 G8 B8 X8). Used by the
// render-target dumps of the native renderer (nba2k13_nativo_volcar_base).
bool EscribirPng(const char* ruta, const uint8_t* rgba, uint32_t ancho, uint32_t alto);

}  // namespace nba2k13::captura
