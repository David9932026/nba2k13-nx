// Interruptores de la migracion del renderizador nativo de nfsmw-nx a este juego.
//
// Los ganchos del renderizador apuntan a funciones del Direct3D del juego de
// referencia (sub_8259BC90, sub_825A5D18, ...). Esas direcciones no existen en el
// codigo recompilado de 2K13: aqui las equivalentes estan en nba2k13_d3d_dir.h y
// hay que migrarlas una a una (fase N2c), no solo cambiar el numero, porque el
// cuerpo de cada gancho tambien lee campos del dispositivo que cambiaron de
// tamano y de sitio.
//
// Mientras eso no este hecho, los ganchos se compilan fuera: asi la parte de
// sistema grafico / destinos / dibujado se puede enlazar y probar en PC sin
// tocar el juego.

#pragma once

// 1 = los ganchos D3D apuntan a las direcciones de ESTE juego (fase N2c).
// 0 = apagados: el juego usa su propio camino y el renderizador nativo solo
//     expone las funciones de sistema.
#define NBA2K13_GANCHOS_D3D 0
