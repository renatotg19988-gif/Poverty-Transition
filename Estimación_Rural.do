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
**************************    Regresion Analysis	  **************************
********************************************************************************

use "$temp\Panel_18_21_Reg.dta", clear
label var  "Identificador de hogar (panel)"
label var post20 "Periodo posterior al COVID-19"

label define sexo_jefe_hogar 1 "Hombre" 0 "Mujer"
label val sexo_jefe_hogar sexo_jefe_hogar

label var limit_jefe_hogar "Jefe con alguna limitación física"
label var accidente_jefe_hogar "Jefe sufrió accidente"

label define agri 1 "Hogar con actividad agrícola" 0 "Otro sector"
label val agri agri

* 0.5 Generar rezago de pobreza (para transiciones)
* --------------------------------------------------------------------------
sort numpanh year
by numpanh: gen pobre_lag = pobre[_n-1]
label var pobre_lag "Estado de pobreza en t-1"

by numpanh: gen pobreza_lag = pobreza[_n-1]
label var pobreza_lag "Estado de pobreza multinomial en t-1"

*----------------------------------------------------*
*---- 2. Probit con Efectos Aleatorios             ---*
*----  Más apropiado para variables binarias        ---*
*----------------------------------------------------*
xtset numpanh year
xtprobit pobre i.area i.year ln_edad_jefe sexo_jefe_hogar bm_jefe  ///
	accidente_jefe_hogar i.nivel_educ_jefe leer_jefe_hogar ///
	limit_jefe_hogar mov_hijo, re
margins, dydx(area)		// Efectos marginales promedio (AME)
estimates store re_probit_area

xtprobit pobre i.prov_rural i.year ln_edad_jefe sexo_jefe_hogar bm_jefe  ///
	accidente_jefe_hogar i.nivel_educ_jefe leer_jefe_hogar ///
	limit_jefe_hogar mov_hijo, re
margins, dydx(prov_rural)
estimates store re_probit_prov

*----------------------------------------------------*
*---- 3. Logit con Efectos Aleatorios              ---*
*----  Alternativa a probit; odds ratios directos   ---*
*----------------------------------------------------*
xtlogit pobre i.area i.year ln_edad_jefe sexo_jefe_hogar bm_jefe  ///
	accidente_jefe_hogar i.nivel_educ_jefe leer_jefe_hogar ///
	limit_jefe_hogar mov_hijo, re or
margins, dydx(area)
estimates store re_logit_area

xtlogit pobre i.prov_rural i.year ln_edad_jefe sexo_jefe_hogar bm_jefe  ///
	accidente_jefe_hogar i.nivel_educ_jefe leer_jefe_hogar ///
	limit_jefe_hogar mov_hijo, re or
margins, dydx(prov_rural)
estimates store re_logit_prov

*----------------------------------------------------*
*---- 4. Logit Poolado con errores clusterizados   ---*
*----  por provincia (más flexible, ignora FE)      ---*
*----------------------------------------------------*
logit pobre i.area i.year ln_edad_jefe sexo_jefe_hogar bm_jefe  ///
	accidente_jefe_hogar i.nivel_educ_jefe leer_jefe_hogar ///
	limit_jefe_hogar mov_hijo [pw=peso], vce(cluster prov)
margins, dydx(area)
estimates store pool_logit_area

logit pobre i.prov_rural i.year ln_edad_jefe sexo_jefe_hogar bm_jefe  ///
	accidente_jefe_hogar i.nivel_educ_jefe leer_jefe_hogar ///
	limit_jefe_hogar mov_hijo [pw=peso], vce(cluster prov)
margins, dydx(prov_rural)
estimates store pool_logit_prov

*----------------------------------------------------*
*---- 5. DiD: Área rural vs urbana × post-2020     ---*
*----  Con efectos fijos y errores robustos         ---*
*----------------------------------------------------*
xtreg pobre i.area##i.post20 ln_edad_jefe sexo_jefe_hogar bm_jefe  ///
	accidente_jefe_hogar i.nivel_educ_jefe leer_jefe_hogar ///
	limit_jefe_hogar mov_hijo, re vce(robust)
margins, dydx(area) at(post20=(0 1))
estimates store did_re_area

xtreg pobre i.prov_rural##i.post20 ln_edad_jefe sexo_jefe_hogar bm_jefe  ///
	accidente_jefe_hogar i.nivel_educ_jefe leer_jefe_hogar ///
	limit_jefe_hogar mov_hijo, re vce(robust)
margins, dydx(prov_rural) at(post20=(0 1))
estimates store did_fe_prov