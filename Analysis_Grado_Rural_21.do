*************** Propuesta de Proyecto:
*************** Migración de la Pobreza
**** Autor: Renato Trujillo

cd "C:\Users\User\Documents\Trabajo\Banco Mundial\Perú\Proyectos\Migración\input\ENAHO 2018-2022"
global temp "C:\Users\User\Documents\Trabajo\Banco Mundial\Perú\Proyectos\Migración\temp"
global dir "C:\Users\User\Documents\Trabajo\Banco Mundial\Perú\Datos"
global enaho "$dir\Input\2018"

clear all
set maxvar 30000

********************************************************************************
************************** 	Extracting panel data	  **************************
********************************************************************************

**** Base de Datos: Módulo 1 - Panel (2018-2021 y 2018-2022) por Hogar
use enaho01-2018-2022-100-panel.dta, clear

preserve
keep if hpan1822 == 1
save "$temp\Modulo1_18_22.dta", replace
restore

preserve
keep if hpan1821 == 1
save "$temp\Modulo1_18_21.dta", replace
restore

**** Base de Datos: Módulo 3 - Panel (2018-2021 y 2018-2022) por Miembro del Hogar
use enaho01a-2018-2022-300-panel.dta, clear

preserve
keep if hpan1822 == 1
save "$temp\Modulo3_18_22.dta", replace
restore

preserve
keep if hpan1821 == 1
save "$temp\Modulo3_18_21.dta", replace
restore

**** Base de Datos: Módulo 4 - Panel (2018-2021 y 2018-2022) por Miembro del Hogar
use enaho01a-2018-2022-400-panel.dta, clear

preserve
keep if hpan1822 == 1
save "$temp\Modulo4_18_22.dta", replace
restore

preserve
keep if hpan1821 == 1
save "$temp\Modulo4_18_21.dta", replace
restore

**** Base de Datos: Módulo 5 - Panel (2018-2021 y 2018-2022) por Miembro del Hogar
use enaho01a-2018-2022-500-panel.dta, clear

preserve
keep if hpan1822 == 1
save "$temp\Modulo5_18_22.dta", replace
restore

preserve
keep if hpan1821 == 1
save "$temp\Modulo5_18_21.dta", replace
restore

**** Base de Datos: Módulo Sumarias - Panel (2018-2021 y 2018-2022) por Hogar
use sumaria-2018-2022-panel.dta, clear

preserve
keep if hpanel_18_22 == 1
save "$temp\Sumarias_18_22.dta", replace
restore

preserve
keep if hpanel_18_21 == 1
save "$temp\Sumarias_18_21.dta", replace
restore

**** Base de Datos: Módulo 6 - Panel (2018-2021 y 2018-2022) por Miembro del Hogar
use enaho01-2018-2022-200-panel.dta, clear

preserve
keep if hpan1822 == 1
save "$temp\Modulo6_18_22.dta", replace
restore

preserve
keep if hpan1821 == 1
save "$temp\Modulo6_18_21.dta", replace
restore

**** Unión de bases

** 2018 - 2021
use "$temp\Modulo3_18_21.dta", clear
merge 1:1 numper using "$temp\Modulo4_18_21.dta", nogen
merge 1:1 numper using "$temp\Modulo5_18_21.dta", nogen
merge 1:1 numper using "$temp\Modulo6_18_21.dta", nogen force

keep numper numpanh* vivienda* p201pcor *conglome* hogar* codperso* ubigeo* dominio* estrato* p203* p207* p208a* p301a??? p302??? p401g1* p401h1* p4024* p506??? p507* p546* p5585a* p558c* fac500*

cap drop numpanh_18 numpanh_19 numpanh_20 numpanh_22
rename numpanh_21 numpanh

merge m:1 numpanh using "$temp\Sumarias_18_21.dta", nogen

save "$temp\Panel_Individuo_18_21.dta", replace

** 2018 - 2022
use "$temp\Modulo3_18_22.dta", clear
merge 1:1 numper using "$temp\Modulo4_18_22.dta", nogen
merge 1:1 numper using "$temp\Modulo5_18_22.dta", nogen
merge 1:1 numper using "$temp\Modulo6_18_22.dta", nogen force

keep numper numpanh* vivienda* p201pcor *conglome* hogar* codperso* ubigeo* dominio* estrato* p203* p207* p208a* p301a??? p302??? p401g1* p401h1* p4024* p506??? p507* p546* p5585a* p558c* fac500*

cap drop numpanh_18 numpanh_19 numpanh_20 numpanh_21
rename numpanh_22 numpanh

merge m:1 numpanh using "$temp\Sumarias_18_22.dta", nogen

save "$temp\Panel_Individuo_18_22.dta", replace

********************************************************************************
************************** 		Defining HH Panel 	  **************************
********************************************************************************

use "$temp\Panel_Individuo_18_21.dta", replace

** Variables del jefe de hogar

*Identificación del jefe de jogar
forvalues i = 18(1)21 {
	cap drop jefe_hogar_`i'
	gen jefe_hogar_`i' = 1 if p203_`i' == 1
	replace jefe_hogar_`i' = 0 if p203_`i' != 1 & p203_`i' != .
}

*Edad del jefe de hogar
forvalues i = 18(1)21 {
	cap drop edad_jefe_hogar_`i'
	gen edad_jefe_hogar_`i' = p208a_`i' if p203_`i' == 1
}

*Sexo del jefe de hogar
forvalues i = 18(1)21 {
	replace p207_`i' = 0 if p207_`i'==2
}

forvalues i = 18(1)21 {
	cap drop sexo_jefe_hogar_`i'
	gen sexo_jefe_hogar_`i' = p207_`i' if p203_`i' == 1
}

*Raza del jefe de hogar
forvalues i = 18(1)21 {
	cap drop raza_jefe_hogar_`i'
	gen raza_jefe_hogar_`i' = p558c_`i' if p203_`i' == 1
}

*Accidente del jefe de hogar
forvalues i = 18(1)21 {
	cap drop accidente_jefe_hogar_`i'
	gen accidente_jefe_hogar_`i' = p4024_`i' if p203_`i' == 1
}

*Años de educación del jefe de hogar
forvalues i = 18(1)21 {
	cap drop educ_jefe_hogar_`i'
	gen educ_jefe_hogar_`i' = p301a_`i' if p203_`i' == 1
}

*Saber leer/escribir del jefe de hogar
forvalues i = 18(1)21 {
	cap drop leer_jefe_hogar_`i'
	gen leer_jefe_hogar_`i' = p302_`i' if p203_`i' == 1
}

*Situación laboral del jefe de hogar
forvalues i = 18(1)21 {
	cap drop trabajo_jefe_hogar_`i'
	gen trabajo_jefe_hogar_`i' = p507_`i' if p203_`i' == 1
}

*Limitación permanente de movimiento del jefe de hogar
forvalues i = 18(1)21 {
	cap drop limit_jefe_hogar_`i'
	gen limit_jefe_hogar_`i' = p401h1_`i' if p203_`i' == 1
}

** Variables por hogar

*Situación de inmigración del hijo del jefe de hogar
forvalues i = 18(1)21 {
	cap drop mov_hijo_`i'
	gen mov_hijo_`i' = 1 if p401g1_`i'== 2 & p203_`i' == 3
	replace mov_hijo_`i' = 0 if p401g1_`i'!= 2 & p401g1_`i'!= . & p203_`i' == 3
}

*Empleados en Agricultura
forvalues i = 18(1)21 {
	cap drop agricultura_`i'
	gen agricultura_`i' = 1 if (p506_`i'>= 111 & p506_`i'<= 200) & (p208a_`i'>=18)
	replace agricultura_`i' = 0 if (p506_`i'< 111 | p506_`i'> 200) & p506_`i'!=. & (p208a_`i'>=18)
	
	gen agri_`i' = agricultura_`i'
	replace agri_`i' = 0 if agri_`i' == .
}

** Construcción de base de datos por hogar
collapse (first)estrato* gashog2d_* mieperho_* linea_* facpanel1821 ubigeo_* pobreza_* (min)edad_jefe_hogar* sexo_jefe_hogar* raza_jefe_hogar* accidente_jefe_hogar* educ_jefe_hogar* leer_jefe_hogar* trabajo_jefe_hogar* limit_jefe_hogar* mov_hijo* (mean)p207* agricultura* (max)agri_* [iw=fac500a_18], by(numpanh)

forvalues i = 18(1)21 {
	label values sexo_jefe_hogar_`i' p207
	label values raza_jefe_hogar_`i' p558c
	label values educ_jefe_hogar_`i' p301a
	label values accidente_jefe_hogar_`i' p4024
	label values leer_jefe_hogar_`i' p302
	label values trabajo_jefe_hogar_`i' p507
	label values limit_jefe_hogar_`i' p401h1
}

save "$temp\Panel_18_21.dta", replace

********************************************************************************
************************** Extracting 2019 statistics **************************
********************************************************************************

use "$enaho\enaho01a-2018-500.dta", replace
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
*---- 	Definición de Ruralidad por provincia	 ----*
*----------------------------------------------------*
cap drop area_act
gen area_act = .
replace area_act = 1 if actividadr3 <= 3 & ocupado == 1
replace area_act = 0 if actividadr3 <= 17 & actividadr3 > 3 & ocupado == 1

keep if area_act != .

tab area_act [iw=fac500a], sort

gen prov = substr(ubigeo,1,4)

collapse (sum)area_act (sum)ocupado [iw=fac500a], by(prov)
cap drop grado_rural
gen grado_rural = area_act/ocupado if area_act!=. & ocupado!=.
save "$temp\Rural_Actividades_18.dta", replace

********************************************************************************
************************** 		District Variables    **************************
********************************************************************************

********************************************************************************
************************** 		Poverty Definition    **************************
********************************************************************************

use "$temp\Panel_18_21.dta", clear
gen prov = substr(ubigeo_18,1,4)
merge m:1 prov using "$temp\Rural_Actividades_18", nogen keep(1 3)

** Definición de Gasto
forvalues i = 18(1)21 {
	cap drop gasto_`i' peso_`i' pobre_`i'
	gen gasto_`i' = gashog2d_`i'/mieperho_`i'/12
	gen pobre_`i' = linea_`i'>=gasto_`i' if (linea_`i' != . & gasto_`i' != .)
}

gen peso = facpanel1821*mieperho_21

forvalues i = 18(1)21 {
	tab pobre_`i' [aw = peso], m
}

********************************************************************************
**************************   Categories Definition    **************************
********************************************************************************

** Definición de provincia como rural (1) o urbana (0)
gen prov_rural = (grado_rural >= 0.4)
lab def prov_rural 1 "Provincia Rural" 0 "Provincia Urbana"
lab val prov_rural prov_rural

** Definición de hogar como rural (1) o urbano (0)
cap drop area
gen area = 0 if estrato_18 <= 5
replace area = 1 if estrato_18 >= 6 & estrato_18 <= 8
lab def area 1 "Hogar Rural" 0 "Hogar Urbano"
lab val area area

** Definición de Categorías Relevantes
cap drop
gen tratamiento = 1 if area==1 & prov_rural==0
replace tratamiento = 0 if area==1 & prov_rural==1
lab def tratamiento 1 "Hogar Rural en Provincia Urbana" 0 "Hogar Rural en Provincia Rural"
lab val tratamiento tratamiento

** Transición de la pobreza por categoría
forvalues i = 18(1)20 {
	local j = `i' + 1
	bys tratamiento: tab pobre_`i' pobre_`j' [iw = facpanel1821], m col
}

********************************************************************************
**************************   Panel Data Definition    **************************
********************************************************************************

** Cambio de forma de la database
reshape long gashog2d_ mieperho_ estrato_ linea_ ubigeo_ pobreza_ ///
edad_jefe_hogar_ sexo_jefe_hogar_ raza_jefe_hogar_ accidente_jefe_hogar_ ///
 leer_jefe_hogar_ trabajo_jefe_hogar_ educ_jefe_hogar_ limit_jefe_hogar_ ///
mov_hijo_ p207_ agricultura_ agri_ gasto_ pobre_, i(numpanh peso prov_rural area tratamiento) j(year)
rename *_ *
replace year = year + 2000
drop if year == 2022

drop estratosocio*
replace leer_jefe_hogar = 0 if leer_jefe_hogar == 2
replace limit_jefe_hogar = 0 if limit_jefe_hogar == 2

** Definición de variable post 2020
gen post20 = (year>= 2020)
lab def post20 1 "Posterior a 2020" 0 "Antes del 2020"
lab val post20 post20

********************************************************************************
**************************   Determinated Variables   **************************
********************************************************************************

** Definición de Blanco/Mestizo vs Otro
gen bm_jefe = (raza_jefe_hogar == 5 | raza_jefe_hogar == 6) if raza_jefe_hogar != .
lab def bm_jefe 1 "Blanco o Mestizo" 0 "Otro"
lab val bm_jefe bm_jefe

** Nivel Educativo
recode educ_jefe_hogar (1/3=1) (4/5=2) (6/9=3) (10=4) (11=5) (12=6), gen(nivel_educ_jefe)
label define nivel_educ_jefe 1 "Sin primaria completa" 2 "Con primaria completa" 3 "Con secundaria completa" 4 "Superior universidad completa" 5 "Postgrado" 6 "Básica especial"
label values nivel_educ_jefe nivel_educ_jefe

** Logaritmo de Edad de jefe de hogar
gen ln_edad_jefe = ln(edad_jefe_hogar)

save "$temp\Panel_18_21_Reg.dta", replace