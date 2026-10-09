*************** Propuesta de Proyecto:
*************** Migración de la Pobreza
**** Autor: Renato Trujillo

cd "C:\Users\User\Documents\Trabajo\Banco Mundial\Perú\Proyectos\Migración\input\ENAHO 2019-2023"
global temp "C:\Users\User\Documents\Trabajo\Banco Mundial\Perú\Proyectos\Migración\temp"

clear all
set maxvar 30000

******** CREACIÓN DE PANEL DE DATOS

**** Base de Datos: Módulo 4 - Solo Observaciones de Panel (2019-2022 y 2019-2023)
use enaho01a-2019-2023-400-panel.dta, clear

preserve
keep if hpanel_19_23 == 1
save "$temp\Modulo4_19_23.dta", replace
restore

preserve
keep if hpanel_19_22 == 1
save "$temp\Modulo4_19_22.dta", replace
restore

**** Base de Datos: Módulo Sumarias - Solo Observaciones de Panel (2019-2022 y 2019-2023)

use sumaria-2019-2023-panel.dta, clear

preserve
keep if hpanel_19_23 == 1
save "$temp\Sumarias_19_23.dta", replace
restore

preserve
keep if hpanel_19_22 == 1
save "$temp\Sumarias_19_22.dta", replace
restore

**** Unión de bases

** 2019 - 2022
use "$temp\Modulo4_19_22.dta", clear
cap drop numpanh_19 numpanh_20 numpanh_21 numpanh_23
rename numpanh_22 numpanh

merge m:1 numpanh using "$temp\Sumarias_19_22.dta", nogen
collapse (first)gashog2d_* mieperho_* linea_* facpanel1922 p401f_* p401g_* ubigeo_* pobreza_*, by(numpanh)

save "$temp\Panel_19_22.dta", replace

** 2019 - 2023
use "$temp\Modulo4_19_23.dta", clear
cap drop numpanh_19 numpanh_20 numpanh_21 numpanh_22
rename numpanh_23 numpanh

merge m:1 numpanh using "$temp\Sumarias_19_23.dta", nogen
collapse (first)gashog2d_* mieperho_* linea_* facpanel1922 p401f_* p401g_* ubigeo_* pobreza_*, by(numpanh)

save "$temp\Panel_19_23.dta", replace

**** Información de Censo 2017
import excel using "Censo_2017.xlsx", sheet("Hogar") firstrow clear
gen grado_urbano = Urbanoencuesta/Total
keep ubigeo grado_urbano Total
save "$temp\Urbano_Hogar", replace

******** DEFINICIÓN DE POBREZA
use "$temp\Panel_19_22.dta", clear

** Definición de Gasto
forvalues i = 19(1)22 {
	cap drop gasto_`i' peso_`i' pobre_`i'
	gen gasto_`i' = gashog2d_`i'/mieperho_`i'/12
	gen pobre_`i' = linea_`i'>=gasto_`i' if (linea_`i' != . & gasto_`i' != .)
}

gen peso = facpanel1922*mieperho_22

forvalues i = 19(1)22 {
	tab pobre_`i' [aw = peso], m
}

******** DEFINICIÓN DE MIGRACIÓN A OTRO DISTRITO

** Verificación de no movimiento
forvalues i = 19(1)22 {
	cap drop categ_migracion_`i'
	* No entran en la categorización aquellos sin información o que no habían nacido
	gen categ_migracion_`i' = . if (p401f_`i' == . | p401f_`i' == 3)
	* Categoría 1: No movimiento
	replace categ_migracion_`i' = 1 if p401f_`i' == 1
	* Verificación de Categoría 1
	destring ubigeo_`i', replace
	replace categ_migracion_`i' = 2 if (p401f_`i' == 1 & p401g_`i' != ubigeo_`i' & p401g_`i' != . & ubigeo_`i' != .)
}

** Definición de grado de urbanización

* Grado de urbanización de hace 5 años
forvalues i = 19(1)22 {
	sort p401g_`i'
	rename p401g_`i' ubigeo
	merge m:1 ubigeo using "$temp\Urbano_Persona", nogen keep(1 3)
	rename grado_urbano grado_urbano_pre_`i'
	rename ubigeo p401g_`i'
}

* Grado de urbanización actual
forvalues i = 19(1)22 {
	sort ubigeo_`i'
	rename ubigeo_`i' ubigeo
	merge m:1 ubigeo using "$temp\Urbano_Persona", nogen keep(1 3)
	rename grado_urbano grado_urbano_`i'
	rename ubigeo ubigeo_`i'
}

** Verificación de cambio a otro distrito por año
forvalues i = 19(1)22 {
	replace categ_migracion_`i' = 1 if (p401g_`i' == ubigeo_`i' & p401g_`i' == . & ubigeo_`i' == .)
}

** Planteamiento de código ubigeo hace 5 años en caso no se haya movido de distrito
forvalues i = 19(1)22 {
	gen missing = (p401g_`i' == .)
	tab categ_migracion_`i' missing, m
	drop missing
	tab categ_migracion_`i' p401f_`i', m
}
* Todos aquellos con 1 en categ_migracion no se han movido de su distrito y tienen missing en p401g

* Agregar el ubigeo y grado de urbanización a aquellos previo
forvalues i = 19(1)22 {
	replace p401g_`i' = ubigeo_`i' if categ_migracion_`i' == 1
	replace grado_urbano_pre_`i' = grado_urbano_`i' if categ_migracion_`i' == 1
}

******** DEFINICIÓN DE CATEGORÍAS DE ACUERDO CON LA MIGRACIÓN

** Planteamiento de categorías para los distritos antes y después
forvalues i = 19(1)22 {
	cap drop urbano_pre_`i' urbano_`i'
	gen urbano_pre_`i' = (grado_urbano_pre_`i'>= 0.6) if grado_urbano_pre_`i'!= .
	gen urbano_`i' = (grado_urbano_`i'>= 0.6) if grado_urbano_`i'!= .
	tab urbano_pre_`i', m
	tab urbano_`i', m
}

** Definición de categorías en movimiento
forvalues i = 19(1)22 {
	* Categoría 2: Migración entre distritos con mismo ámbito
	replace categ_migracion_`i' = 2 if (p401f_`i' == 2 & urbano_pre_`i' == urbano_`i' & urbano_pre_`i' != . & urbano_`i' != .)
	* Categoría 3: Migración de distritos rurales a urbanos
	replace categ_migracion_`i' = 3 if (p401f_`i' == 2 & urbano_pre_`i' == 0 & urbano_`i' == 1)
	* Categoría 4: Migración de distritos urbanos a rurales
	replace categ_migracion_`i' = 4 if (p401f_`i' == 2 & urbano_pre_`i' == 1 & urbano_`i' == 0)
}

** Revisión de las categorías

* Contraste con la variable de cambio de distrito
forvalues i = 19(1)22 {
	tab categ_migracion_`i' p401f_`i', m
}

* Chequeo de información en aquellos con movimiento pero sin categoría
forvalues i = 19(1)22 {
	tab p401g_`i' ubigeo_`i' if categ_migracion_`i' == . & p401f_`i' == 2, m
	tab urbano_pre_`i' urbano_`i' if categ_migracion_`i' == . & p401f_`i' == 2, m
}
* Todos los missings no debidos (p401f == 2) se deben a un mal código de ubigeo del distrito de hace 5 años

******** ANÁLISIS DESCRIPTIVO DE LAS CATEGORÍAS

** Categoría x Pobreza por año
forvalues i = 19(1)22 {
	tab categ_migracion_`i' pobreza_`i', m
}

** Categoría conjunta de todos los años
cap drop categ_migracion
gen categ_migracion = .
*Categoría 1: No Movimiento
replace categ_migracion = 1 if (categ_migracion_19 == 1 | categ_migracion_20 == 1 | categ_migracion_21 == 1 | categ_migracion_22 == 1)
* Categoría 2: Migración entre distritos con mismo ámbito
replace categ_migracion = 2 if (categ_migracion_19 == 2 | categ_migracion_20 == 2 | categ_migracion_21 == 2 | categ_migracion_22 == 2)
* Categoría 3: Migración de distritos rurales a urbanos
replace categ_migracion = 3 if (categ_migracion_19 == 3 | categ_migracion_20 == 3 | categ_migracion_21 == 3 | categ_migracion_22 == 3)
* Categoría 4: Migración de distritos urbanos a rurales
replace categ_migracion = 4 if (categ_migracion_19 == 4 | categ_migracion_20 == 4 | categ_migracion_21 == 4 | categ_migracion_22 == 4)

** Distribución de la categoría
tab categ_migracion, m

** Transición de la pobreza por categoría
forvalues i = 19(1)21 {
	local j = `i' + 1
	bys categ_migracion: tab pobre_`i' pobre_`j', m
	bys categ_migracion: tab pobre_`i' pobre_`j' [iw = peso], m
}