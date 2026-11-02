// Servicios de la app que el renderizador nativo de nfsmw-nx usa y que en 2K13 no
// existen (o no hacen falta). Se definen aqui como no-ops para que el enlazado pase
// y para que el motor no dependa de modulos que pertenecen al juego de NFS.
//
// Nada de esto toca el camino de dibujado: son instrumentacion y palancas de
// calidad que 2K13 no tiene implementadas todavia. Cuando portemos la parte que
// las use de verdad (recorte de sombras, LOD de escenario, reflejo de asfalto),
// se sustituyen por las versiones reales.

#include <rex/platform.h>

#include <atomic>
#include <cstdint>
#include <string>

#include "nba2k13_ajustes_graficos.h"
#include "nba2k13_nativo_ganchos.h"

// Contador de fotogramas de juego. En NFS lo incrementa el gancho de Swap
// (nfsmw_d3d_trace.cpp); el renderizador nativo lo lee para saber en que
// fotograma esta (nba2k13_nativo_sistema.cpp lo declara como extern global).
std::atomic<uint64_t> g_NBA2K13_fotogramas_juego{0};

namespace nba2k13::guardia30 {

// Guardia de 30 FPS de NFS: mira cuanto tarda el fotograma y, si se pasa,
// recorta sombras. 2K13 no tiene esa palanca; Latir solo toma nota (no-op) y
// SinSombras respeta lo que pida el usuario sin recortar nada por su cuenta.
void Latir(double ms) {
  (void)ms;
}

void Informe() {}

bool SinSombras(bool del_usuario) {
  return del_usuario;
}

}  // namespace nba2k13::guardia30

namespace nba2k13::escenario_lod {

// Resumen del gancho de LOD de escenario (nfsmw_escenario_lod.cpp): en NFS
// reescribe la tabla de LOD para sostener los 30 FPS. En 2K13 no hay gancho.
std::string Resumen() {
  return "sin gancho de LOD (no portado)";
}

}  // namespace nba2k13::escenario_lod

namespace nba2k13::render_targets {

// Muestras (MSAA) originales de cada modo de presentacion. NFS las guarda para
// poder restaurarlas porque fuerza sus propios modos. 2K13 no toca la tabla de
// modos: el valor honesto es 1 (sin MSAA), que es lo que devuelve tambien el
// camino de los modos pequenos.
uint32_t MuestrasOriginalesModoActual(const uint8_t* base) {
  (void)base;
  return 1;
}

}  // namespace nba2k13::render_targets

namespace nba2k13::reflejo_demanda {

// Seguimiento del reflejo del asfalto de NFS (solo se resuelve si alguien lo
// mira). En 2K13 no hay reflejo de ese tipo: todo apagado.
void AnotarCopia() {}
void AnotarLectura() {}
void AnotarOculto() {}
void AnotarSwap() {}
void AnotarTestigo(bool con_muestras) {
  (void)con_muestras;
}
void AnotarVisible(bool medido) {
  (void)medido;
}
bool MedirVisibilidad() {
  return false;
}
bool VisibilidadComprobada() {
  return false;
}

}  // namespace nba2k13::reflejo_demanda

namespace nba2k13::ajustes {

// Posproceso y FXAA del menu de NFS: apagados (la salida queda bit a bit igual).
Posproceso LeerPosproceso() {
  return Posproceso{};
}

uint64_t VersionPosproceso() {
  return 0;
}

bool AntialiasingFxaa() {
  return false;
}

// Tratamiento visual (contraste/saturacion/viñeta del menu de NFS): 0 = ninguno.
int TratamientoVisual() {
  return 0;
}

}  // namespace nba2k13::ajustes

namespace nba2k13::nat {

// Consumidor de marcadores del anillo: en NFS lo enciende el hilo del anillo para
// identificar cada dibujado sin mirar la cola. Aqui todavia no hay marcadores que
// consumir, asi que se queda apagado (el sistema cae al camino normal).
void ActivarConsumidorMarcadores(bool activo) {
  (void)activo;
}

void AnotarComprobacionMarcador(bool igual, uint32_t secuencia, uint32_t registro, uint32_t en_registros,
                                uint32_t en_marcador) {
  (void)igual;
  (void)secuencia;
  (void)registro;
  (void)en_registros;
  (void)en_marcador;
}

}  // namespace nba2k13::nat
