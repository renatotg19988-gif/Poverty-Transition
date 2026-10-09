*************** Propuesta de Proyecto:
*************** Migración de la Pobreza
**** Autor: Renato Trujillo

cd "C:\Users\User\Documents\Trabajo\Banco Mundial\Perú\Proyectos\Migración\input\ENAHO 2019-2023"
global temp "C:\Users\User\Documents\Trabajo\Banco Mundial\Perú\Proyectos\Migración\temp"
global dir "C:\Users\User\Documents\Trabajo\Banco Mundial\Perú\Datos"
global enaho "$dir\Input\2019"

clear all
set maxvar 30000

********************************************************************************
************************** 	Extracting panel data	  **************************
********************************************************************************

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

save "$temp\Panel_19_22.dta", replace

** 2019 - 2023
use "$temp\Modulo4_19_23.dta", clear
cap drop numpanh_19 numpanh_20 numpanh_21 numpanh_22
rename numpanh_23 numpanh

merge m:1 numpanh using "$temp\Sumarias_19_23.dta", nogen

save "$temp\Panel_19_23.dta", replace

********************************************************************************
************************** Extracting 2019 statistics **************************
********************************************************************************

use "$enaho\enaho01a-2019-500.dta", replace
rename a?o year

keep year conglome vivienda hogar codperso ocu500 p207 p500i ocupinf estrato dominio p204 p205 p206 fac500a ocupinf p507 p506 p558c emplpsec i524a1 d529t i530a d536 i538a1 d540t i541a d543 d544t ubigeo

*Urban/Rural
gen area = 1 if estrato <= 5
replace area = 2 if estrato >= 6 & estrato <= 8
lab def area 1 "urbano" 2 "rural"
lab val area area

*Only habitual residents
gen resi = 1 if ((p204==1 & p205==2) | (p204==2 & p206==1))
keep if resi == 1

*Dropping observations who do not belong to the survey
destring p500i, replace
drop if p500i == 0

drop if ocu500 == 0

*Crear ingreso proveniente del trabajo
egen ingtrabw = rowtotal(i524a1 d529t i530a d536 i538a1 d540t i541a d543 d544t)
gen  ingtrabw_m = ingtrabw / 12
label var ingtrabw "Ingreso del trabajo anual"
label var ingtrabw_m "Ingreso del trabajo mensual"

destring year, replace

*----------------------------------------------------*
*---- 		Estructura del mercado laboral		 ----*
*----------------------------------------------------*
gen pet     = 1
gen pea     = (ocu500 <= 3)
gen ocupado = (ocu500 == 1) if pea == 1

tab pea [iw=fac500a]
tab ocupado [iw=fac500a]
table ocupinf [iw=fac500a]

recode p506 (111/200=1) (500=2) (1010/1429=3) (1500/3720=4) (4010/4100=5) (4510/4550=6) (5010/5270=7) (5510/5520=8) (6010/6420=9) (6510/6720=10) (7010/7499=11) (7510/7530=12) (8010/8090=13) (8510/8532=14) (9000/9309=15) (9500=16) (9900/9999=17), gen(actividadr3)
label define actividadr3 1 "Agricultura, Ganaderia, Caza y Silvicultura" 2 "Pesca" 3 "Explotacion de Minas y Canteras" 4 "Industrias Manufactureras" 5 "Suministro de electricidad, gas y agua" 6 "Construccion" 7 "Comercio" 8 "Hoteles y Restaurantes" 9 "Transporte, Almacenamiento y Comunicaciones" 10 "Intermediacion Financiera" 11 "Actividades Inmobiliarias, Empresariales y de Alquiler" 12 "Administracion Publica" 13 "Enseñanza" 14 "Actividades de Servicios Sociales y de Salud (Privada)" 15 "Otras ctividades de Servicios Comunitarias, sociales y personales" 16 "Hogares Privados con servicio domestico" 17 "Organizaciones y Organos extraterritoriales"
label values actividadr3 actividadr3

tab actividadr3 [iw=fac500a], sort

*Qué tan rurales son las actividades en Perú?
table actividadr3 area [iw=fac500a]
tab actividadr3 area [iw=fac500a], row

*----------------------------------------------------*
*---- 	Definición de Ruralidad por distrito	 ----*
*----------------------------------------------------*
cap drop area_act
gen area_act = .
replace area_act = 1 if actividadr3 <= 3 & ocupado == 1
replace area_act = 0 if actividadr3 <= 17 & actividadr3 > 3 & ocupado == 1

keep if area_act != .

tab area_act [iw=fac500a], sort

collapse (sum)area_act (sum)ocupado [iw=fac500a], by(ubigeo)
cap drop grado_rural
gen grado_rural = area_act/ocupado if area_act!=. & ocupado!=.

rename ubigeo ubigeo_19
save "$temp\Rural_Actividades.dta", replace

********************************************************************************
************************** 		Poverty Definition    **************************
********************************************************************************

use "$temp\Panel_19_22.dta", clear
merge m:1 ubigeo_19 using "$temp\Rural_Actividades", nogen keep(1 3)

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

********************************************************************************
**************************   Categories Definition    **************************
********************************************************************************

** Definición de categoría
gen distrito_rural = (grado_rural >= 0.4)

** Transición de la pobreza por categoría
forvalues i = 19(1)21 {
	local j = `i' + 1
	bys distrito_rural: tab pobre_`i' pobre_`j' [iw = facpanel1922], m col
}