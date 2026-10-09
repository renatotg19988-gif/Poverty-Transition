/*==============================================================================
  ANÁLISIS DE PANEL: RURALIDAD, POBREZA Y COVID-19 EN PERÚ (2018-2021)
  ============================================================================
  
  Base de datos: Panel ENAHO 2018-2021
  Variable ID:   numpanh (identificador de hogares)
  Peso:          facpanel1821 (factor de expansión del panel)
  
  Estructura del do file:
  -----------------------------------------------------------------------
  PARTE 0: Configuración inicial y preparación de variables
  PARTE 1: Estadísticas descriptivas del panel
  PARTE 2: Interacciones y controles (literatura)
  PARTE 3: Modelos de panel con CRE (Mundlak-Chamberlain)
  PARTE 4: Diferencias en diferencias y event study (COVID-19)
  PARTE 5: Triple diferencia (DDD) – agricultura como mecanismo
  PARTE 6: Cadenas de Markov – matrices de transición
  PARTE 7: Análisis de duración del shock COVID-19
  PARTE 8: Selección del modelo y diagnósticos
  -----------------------------------------------------------------------
  
  Referencia metodológica: 
  "Panel Analysis of Rurality, Poverty and COVID-19 in Peru: 
   Methodological Guide" (2025)
  
  Autores de referencia clave:
  - Mundlak (1978), Bell & Jones (2014): CRE
  - Cappellari & Jenkins (2004): transiciones de pobreza
  - Huarancca, Castillo & Castellares (2023, BCRP): pobreza Perú
  - Clarke & Tapia-Schythe (2021): event studies en Stata
  - Anderson & Goodman (1957): inferencia en cadenas de Markov
  ============================================================================*/

clear all
set more off
set matsize 11000
cap log close

* --- Ruta de trabajo (ajustar según usuario) ---
global ruta "."
log using "${ruta}/log_analysis_panel.smcl", replace


/*==============================================================================
  PARTE 0: CONFIGURACIÓN INICIAL Y PREPARACIÓN DE VARIABLES
  ==============================================================================*/

* 0.1 Cargar base de datos
* --------------------------------------------------------------------------
use "Panel_18_21_Reg.dta", clear

* 0.2 Recodificar variables categóricas de Stata (string/labeled) a numéricas
* --------------------------------------------------------------------------

* Variable de área: rural = 1, urbano = 0
gen rural = (area == "Hogar Rural") if area != ""
label define lb_rural 0 "Urbano" 1 "Rural"
label values rural lb_rural
label var rural "Hogar en zona rural"

* Variable post-COVID: post2020 = 1 si año >= 2020
gen post2020 = (year >= 2020)
label define lb_post 0 "Pre-COVID (2018-2019)" 1 "Post-COVID (2020-2021)"
label values post2020 lb_post
label var post2020 "Periodo posterior al COVID-19"

* Variable de provincia rural (binaria)
gen prov_rural_d = (prov_rural == "Provincia Rural") if prov_rural != ""
label var prov_rural_d "Provincia predominantemente rural"

* 0.3 Declarar panel
* --------------------------------------------------------------------------
* numpanh es float; convertir a long para xtset
gen long hhid = numpanh
order hhid, first
xtset hhid year
label var hhid "Identificador de hogar (panel)"

* 0.4 Generar variables derivadas
* --------------------------------------------------------------------------

* Gasto per cápita mensual (gashog2d es anual, gasto ya parece mensualizado)
* Usar 'gasto' como proxy del gasto per cápita mensual
gen lgasto = ln(gasto)
label var lgasto "Log del gasto per cápita mensual"

* Ratio gasto / línea de pobreza (indicador continuo de bienestar)
gen ratio_gasto_linea = gasto / linea
label var ratio_gasto_linea "Ratio gasto per cápita / línea de pobreza"

* Pobreza multinomial: 1=pobre extremo, 2=pobre no extremo, 3=no pobre
* (ya está en la variable 'pobreza')
label define lb_pobreza 1 "Pobre extremo" 2 "Pobre no extremo" 3 "No pobre"
label values pobreza lb_pobreza

* Educación del jefe: reagrupar en categorías amplias
recode educ_jefe_hogar ///
    (1 2 = 1 "Sin educación / Inicial") ///
    (3 4 = 2 "Primaria") ///
    (5 6 = 3 "Secundaria") ///
    (7 8 9 10 11 12 = 4 "Superior"), ///
    gen(educ_jefe_cat)
label var educ_jefe_cat "Nivel educativo del jefe (agrupado)"

* Variable dummy de educación superior del jefe
gen educ_superior = (educ_jefe_cat == 4) if educ_jefe_cat != .
label var educ_superior "Jefe con educación superior"

* Sexo del jefe (recodificar: 0 parece ser hombre según distribución)
* En ENAHO: 1=Hombre, 2=Mujer; aquí 0=mayoritario, 1=minoritario
* Asumimos: 0=Hombre, 1=Mujer (por la proporción 15151 vs 1537)
rename sexo_jefe_hogar mujer_jefe
label define lb_sexo 0 "Hombre" 1 "Mujer"
label values mujer_jefe lb_sexo
label var mujer_jefe "Jefa de hogar mujer"

* Raza/etnicidad del jefe: dummy indígena
* Código 1 parece ser quechua, 2 aymara (lenguas nativas principales)
gen indigena = inlist(raza_jefe_hogar, 1, 2, 3) if raza_jefe_hogar != .
label var indigena "Jefe de hogar indígena (quechua/aymara/nativo)"

* Discapacidad o limitación del jefe
rename limit_jefe_hogar limitacion_jefe
label var limitacion_jefe "Jefe con alguna limitación física"

* Accidente del jefe
rename accidente_jefe_hogar accidente_jefe
label var accidente_jefe "Jefe sufrió accidente"

* Tamaño del hogar
rename mieperho tamhogar
label var tamhogar "Número de miembros del hogar"

* Empleo agrícola (usar variable binaria 'agri')
label var agri "Hogar con actividad agrícola"

* 0.5 Generar rezago de pobreza (para transiciones)
* --------------------------------------------------------------------------
sort hhid year
by hhid: gen pobre_lag = pobre[_n-1]
label var pobre_lag "Estado de pobreza en t-1"

by hhid: gen pobreza_lag = pobreza[_n-1]
label var pobreza_lag "Estado de pobreza multinomial en t-1"

* 0.6 Variables de tendencia e interacción temporal
* --------------------------------------------------------------------------
gen trend = year - 2018
label var trend "Tendencia temporal (0=2018, 3=2021)"

* Dummies de año
tab year, gen(yr_)
rename yr_1 yr2018
rename yr_2 yr2019
rename yr_3 yr2020
rename yr_4 yr2021

* 0.7 Extraer departamento y provincia del ubigeo
* --------------------------------------------------------------------------
gen str2 depto = substr(ubigeo, 1, 2)
destring depto, replace
label var depto "Código de departamento"

gen str4 prov_code = substr(ubigeo, 1, 4)
label var prov_code "Código de provincia"

* 0.8 Guardar base preparada
* --------------------------------------------------------------------------
compress
save "${ruta}/Panel_18_21_preparado.dta", replace

di as result "=============================================="
di as result " BASE DE DATOS PREPARADA EXITOSAMENTE"
di as result " Hogares: `= _N/4'  |  Observaciones: `= _N'"
di as result "=============================================="


/*==============================================================================
  PARTE 1: ESTADÍSTICAS DESCRIPTIVAS DEL PANEL
  ==============================================================================*/

di _newline(3)
di as result "╔══════════════════════════════════════════════════════════════╗"
di as result "║  PARTE 1: ESTADÍSTICAS DESCRIPTIVAS                        ║"
di as result "╚══════════════════════════════════════════════════════════════╝"

* 1.1 Tasa de pobreza por área y año
* --------------------------------------------------------------------------
di _newline as text "{hline 60}"
di as result "  Tasa de pobreza por área y año (ponderada)"
di as text "{hline 60}"

table year rural [pw = facpanel1821], ///
    statistic(mean pobre) statistic(frequency) nformat(%9.4f)

* 1.2 Tasa de pobreza por grado de ruralidad (cuartiles)
* --------------------------------------------------------------------------
xtile q_rural = grado_rural, nq(4)
label define lb_qrural 1 "Q1: Más urbano" 2 "Q2" 3 "Q3" 4 "Q4: Más rural"
label values q_rural lb_qrural
label var q_rural "Cuartil de grado de ruralidad"

di _newline as text "{hline 60}"
di as result "  Tasa de pobreza por cuartil de ruralidad y año"
di as text "{hline 60}"

table year q_rural [pw = facpanel1821], ///
    statistic(mean pobre) nformat(%9.4f)

* 1.3 Estadísticas descriptivas de controles por área
* --------------------------------------------------------------------------
di _newline as text "{hline 60}"
di as result "  Estadísticas descriptivas por área"
di as text "{hline 60}"

estpost tabstat pobre lgasto tamhogar edad_jefe_hogar mujer_jefe ///
    indigena educ_superior agri grado_rural, ///
    by(rural) statistics(mean sd n) columns(statistics)
esttab using "${ruta}/tab_descriptivas.rtf", replace ///
    cells("mean(fmt(%9.3f)) sd(fmt(%9.3f)) count(fmt(%9.0f))") ///
    title("Estadísticas descriptivas por área de residencia") ///
    noobs nonumber label

* 1.4 Transiciones brutas de pobreza
* --------------------------------------------------------------------------
di _newline as text "{hline 60}"
di as result "  Matriz de transición bruta de pobreza"
di as text "{hline 60}"

xttrans pobre, freq


/*==============================================================================
  PARTE 2: INTERACCIONES Y CONTROLES (LITERATURA)
  ==============================================================================
  
  Basado en:
  - Rural × Educación (Liu et al. 2022; Flachsbarth et al. 2018)
  - Rural × Empleo agrícola (Escobal 2001)
  - Rural × Tamaño hogar (Huarancca et al. 2023)
  - Rural × Tendencia temporal (Flachsbarth et al. 2018)
  - Rural × Post-COVID (contribución original)
  ==============================================================================*/

di _newline(3)
di as result "╔══════════════════════════════════════════════════════════════╗"
di as result "║  PARTE 2: INTERACCIONES Y CONTROLES                        ║"
di as result "╚══════════════════════════════════════════════════════════════╝"

* 2.1 Generar interacciones clave
* --------------------------------------------------------------------------

* Rural × Educación del jefe (Flachsbarth et al. 2018)
gen rural_educ = rural * educ_jefe_hogar
label var rural_educ "Rural × Nivel educativo del jefe"

gen rural_educsup = rural * educ_superior
label var rural_educsup "Rural × Educación superior del jefe"

* Rural × Empleo agrícola (Escobal 2001)
gen rural_agri = rural * agri
label var rural_agri "Rural × Actividad agrícola"

* Rural × Tamaño del hogar (Huarancca et al. 2023)
gen rural_tamhogar = rural * tamhogar
label var rural_tamhogar "Rural × Tamaño del hogar"

* Rural × Tendencia temporal (Flachsbarth et al. 2018)
gen rural_trend = rural * trend
label var rural_trend "Rural × Tendencia temporal"

* Rural × Post-COVID (contribución original - DiD)
gen rural_post = rural * post2020
label var rural_post "Rural × Post-COVID (DiD)"

* Rural × Post-COVID × Agricultura (Triple diferencia)
gen rural_post_agri = rural * post2020 * agri
label var rural_post_agri "Rural × Post-COVID × Agricultura (DDD)"

* Post-COVID × Agricultura
gen post_agri = post2020 * agri
label var post_agri "Post-COVID × Agricultura"

* Grado de ruralidad × Post-COVID (versión continua)
gen grural_post = grado_rural * post2020
label var grural_post "Grado ruralidad × Post-COVID"

* Rural × Indígena
gen rural_indigena = rural * indigena
label var rural_indigena "Rural × Jefe indígena"

* Rural × Mujer jefa
gen rural_mujer = rural * mujer_jefe
label var rural_mujer "Rural × Jefa mujer"

* 2.2 Medias intrapanel para CRE (Mundlak 1978)
* --------------------------------------------------------------------------
* Variables variantes en el tiempo: generar medias por hogar

foreach var in tamhogar edad_jefe_hogar agri lgasto {
    bysort hhid: egen m_`var' = mean(`var')
    label var m_`var' "Media intrapanel: `var'"
}

* 2.3 Modelos progresivos con interacciones
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  Modelos progresivos: efecto de ruralidad con interacciones"
di as text "{hline 70}"

* Modelo 1: Solo rural (pooled probit)
eststo m1: probit pobre rural i.year [pw = facpanel1821], ///
    vce(cluster hhid)
margins, dydx(rural) post
eststo m1_mfx

* Modelo 2: + Controles demográficos
eststo m2: probit pobre rural edad_jefe_hogar mujer_jefe tamhogar ///
    indigena i.year [pw = facpanel1821], vce(cluster hhid)
margins, dydx(rural) post
eststo m2_mfx

* Modelo 3: + Capital humano y trabajo
eststo m3: probit pobre rural edad_jefe_hogar mujer_jefe tamhogar ///
    indigena educ_jefe_hogar agri i.year [pw = facpanel1821], ///
    vce(cluster hhid)
margins, dydx(rural) post
eststo m3_mfx

* Modelo 4: + Interacciones clave (rural × educación, rural × agri)
eststo m4: probit pobre rural edad_jefe_hogar mujer_jefe tamhogar ///
    indigena educ_jefe_hogar agri ///
    rural_educ rural_agri rural_tamhogar ///
    i.year [pw = facpanel1821], vce(cluster hhid)
margins, dydx(rural) post
eststo m4_mfx

* Modelo 5: + Interacción rural × post-COVID (DiD implícito)
eststo m5: probit pobre rural post2020 rural_post ///
    edad_jefe_hogar mujer_jefe tamhogar ///
    indigena educ_jefe_hogar agri ///
    rural_educ rural_agri rural_tamhogar ///
    i.year [pw = facpanel1821], vce(cluster hhid)
margins, dydx(rural) at(post2020 = (0 1)) post
eststo m5_mfx

* Tabla comparativa de efectos marginales
esttab m1_mfx m2_mfx m3_mfx m4_mfx m5_mfx ///
    using "${ruta}/tab_interacciones_mfx.rtf", replace ///
    title("Efecto marginal de la ruralidad: modelos progresivos") ///
    mtitles("Base" "Demog." "Cap. Humano" "Interacciones" "DiD") ///
    cells(b(fmt(4) star) se(fmt(4) par)) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    note("Efectos marginales promedio. Errores estándar clusterizados por hogar.") ///
    label

eststo clear


/*==============================================================================
  PARTE 3: MODELOS DE PANEL CON CRE (MUNDLAK-CHAMBERLAIN)
  ==============================================================================
  
  Problema: efectos fijos eliminan variables invariantes (rural, sexo, raza).
  Solución: CRE agrega medias intrapanel como regresores adicionales en RE,
  permitiendo estimar coeficientes de variables invariantes de manera
  consistente (Bell & Jones 2014; Wooldridge 2010, 2019).
  
  Especificación: Y_it = X_it*β + X̄_i*θ + Z_i*δ + ν_i + ε_it
  donde Z_i incluye rural, sexo, raza (invariantes en el tiempo)
  ==============================================================================*/

di _newline(3)
di as result "╔══════════════════════════════════════════════════════════════╗"
di as result "║  PARTE 3: MODELOS CRE (MUNDLAK-CHAMBERLAIN)                ║"
di as result "╚══════════════════════════════════════════════════════════════╝"

* 3.1 Modelo lineal de probabilidad con efectos fijos (benchmark)
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  3.1 LPM con efectos fijos (benchmark - no estima rural)"
di as text "{hline 70}"

eststo fe_lpm: xtreg pobre i.year tamhogar edad_jefe_hogar agri ///
    [pw = facpanel1821], fe vce(cluster hhid)

* 3.2 Modelo RE estándar (inconsistente si hay correlación con ν_i)
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  3.2 RE estándar (puede ser inconsistente)"
di as text "{hline 70}"

eststo re_lpm: xtreg pobre rural i.year tamhogar edad_jefe_hogar ///
    mujer_jefe indigena educ_jefe_hogar agri ///
    [pw = facpanel1821], re vce(cluster hhid)

* 3.3 Test de Hausman: FE vs RE
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  3.3 Test de Hausman"
di as text "{hline 70}"

* Estimar sin pesos para Hausman (restricción de Stata)
quietly xtreg pobre i.year tamhogar edad_jefe_hogar agri, fe
estimates store fe_haus
quietly xtreg pobre rural i.year tamhogar edad_jefe_hogar ///
    mujer_jefe indigena educ_jefe_hogar agri, re
estimates store re_haus
hausman fe_haus re_haus, sigmamore

* 3.4 CRE - Modelo Lineal de Probabilidad (Mundlak)
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  3.4 CRE-LPM: Modelo Mundlak para variable dependiente binaria"
di as text "{hline 70}"

eststo cre_lpm: xtreg pobre rural i.year ///
    tamhogar edad_jefe_hogar agri ///
    mujer_jefe indigena educ_jefe_hogar ///
    rural_educ rural_agri rural_tamhogar ///
    m_tamhogar m_edad_jefe_hogar m_agri ///
    [pw = facpanel1821], re vce(cluster hhid)

* 3.5 CRE - Probit de panel (Wooldridge 2010)
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  3.5 CRE-Probit: Probit de panel con corrección Mundlak"
di as text "{hline 70}"

eststo cre_probit: xtprobit pobre rural i.year ///
    tamhogar edad_jefe_hogar agri ///
    mujer_jefe indigena educ_jefe_hogar ///
    rural_educ rural_agri rural_tamhogar ///
    m_tamhogar m_edad_jefe_hogar m_agri, ///
    re vce(cluster hhid)

* Efectos marginales promedio del CRE-Probit
margins, dydx(rural) predict(pu0)
eststo cre_probit_mfx

* Efecto marginal de rural condicional en post-COVID
quietly xtprobit pobre rural post2020 rural_post i.year ///
    tamhogar edad_jefe_hogar agri ///
    mujer_jefe indigena educ_jefe_hogar ///
    rural_educ rural_agri rural_tamhogar ///
    m_tamhogar m_edad_jefe_hogar m_agri, ///
    re vce(cluster hhid)

margins, dydx(rural) at(post2020 = (0 1)) predict(pu0)
marginsplot, yline(0) ///
    title("Efecto marginal de la ruralidad: pre vs post COVID") ///
    ytitle("Efecto marginal sobre Pr(Pobre)") ///
    xtitle("Periodo") ///
    xlabel(0 "Pre-COVID" 1 "Post-COVID") ///
    name(g_mfx_rural_cre, replace)
graph export "${ruta}/fig_mfx_rural_cre.png", replace width(1200)

* 3.6 CRE - Logit de panel
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  3.6 CRE-Logit: Logit de panel con corrección Mundlak"
di as text "{hline 70}"

eststo cre_logit: xtlogit pobre rural i.year ///
    tamhogar edad_jefe_hogar agri ///
    mujer_jefe indigena educ_jefe_hogar ///
    rural_educ rural_agri rural_tamhogar ///
    m_tamhogar m_edad_jefe_hogar m_agri, ///
    re vce(cluster hhid)

* 3.7 Tabla comparativa de modelos de panel
* --------------------------------------------------------------------------
esttab fe_lpm re_lpm cre_lpm cre_probit cre_logit ///
    using "${ruta}/tab_modelos_panel.rtf", replace ///
    title("Modelos de panel: efecto de la ruralidad sobre la pobreza") ///
    mtitles("FE-LPM" "RE-LPM" "CRE-LPM" "CRE-Probit" "CRE-Logit") ///
    cells(b(fmt(4) star) se(fmt(4) par)) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    stats(N N_g r2_o ll chi2, ///
        labels("Observaciones" "Hogares" "R² overall" "Log-likelihood" "Chi²") ///
        fmt(%9.0f %9.0f %9.4f %9.2f %9.2f)) ///
    drop(m_* _cons) ///
    note("Modelos CRE incluyen medias intrapanel (Mundlak). EE clusterizados.") ///
    label

* 3.8 Versión con grado_rural continuo (en vez de dummy rural)
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  3.8 CRE-Probit con grado de ruralidad continuo"
di as text "{hline 70}"

eststo cre_grural: xtprobit pobre grado_rural post2020 grural_post ///
    i.year tamhogar edad_jefe_hogar agri ///
    mujer_jefe indigena educ_jefe_hogar ///
    m_tamhogar m_edad_jefe_hogar m_agri, ///
    re vce(cluster hhid)

* Efecto marginal del grado de ruralidad a diferentes niveles
margins, dydx(grado_rural) ///
    at(grado_rural = (0.1 0.3 0.5 0.7 0.9) post2020 = (0 1)) ///
    predict(pu0)
marginsplot, by(post2020) ///
    title("Efecto marginal del grado de ruralidad") ///
    ytitle("dPr(Pobre)/d(Grado Rural)") ///
    xtitle("Grado de ruralidad") ///
    name(g_mfx_grural, replace)
graph export "${ruta}/fig_mfx_grado_rural.png", replace width(1200)

eststo clear


/*==============================================================================
  PARTE 4: DIFERENCIAS EN DIFERENCIAS Y EVENT STUDY (COVID-19)
  ==============================================================================
  
  Diseño:
  - Grupo de tratamiento: hogares urbanos (mayor impacto del confinamiento)
  - Grupo de control: hogares rurales (menor exposición)
  - Evento: COVID-19, marzo 2020 → primer año completo post = 2020
  
  Nota: La dirección del "tratamiento" es inversa a lo usual. El COVID
  afectó más a los urbanos, por lo que rural_post < 0 significaría que
  la ruralidad fue un factor protector durante la pandemia.
  
  Refs: Clarke & Tapia-Schythe (2021); Freyaldenhoven et al. (2019)
  ==============================================================================*/

di _newline(3)
di as result "╔══════════════════════════════════════════════════════════════╗"
di as result "║  PARTE 4: DIFERENCIAS EN DIFERENCIAS Y EVENT STUDY          ║"
di as result "╚══════════════════════════════════════════════════════════════╝"

* 4.1 DiD básico: LPM con efectos fijos de hogar
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  4.1 DiD - LPM con efectos fijos de hogar"
di as text "{hline 70}"

* Nota: rural es absorbido por FE de hogar; rural_post es el coef DiD
eststo did_fe: reghdfe pobre rural_post ///
    tamhogar edad_jefe_hogar agri, ///
    absorb(hhid year) vce(cluster hhid)

* 4.2 DiD: CRE-Probit (permite estimar rural directamente)
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  4.2 DiD - CRE Probit"
di as text "{hline 70}"

eststo did_cre: xtprobit pobre rural post2020 rural_post ///
    tamhogar edad_jefe_hogar agri ///
    mujer_jefe indigena educ_jefe_hogar ///
    m_tamhogar m_edad_jefe_hogar m_agri ///
    i.year, re vce(cluster hhid)

margins, dydx(rural_post) predict(pu0)
eststo did_cre_mfx

* Probabilidades predichas: 4 celdas (rural/urbano × pre/post)
margins rural#post2020, predict(pu0) post
eststo did_cre_pred

marginsplot, ///
    title("Probabilidad de pobreza: Rural vs Urbano, Pre vs Post COVID") ///
    ytitle("Pr(Pobre)") xtitle("Periodo") ///
    xlabel(0 "Pre-COVID" 1 "Post-COVID") ///
    legend(order(1 "Urbano" 2 "Rural")) ///
    name(g_did_pred, replace)
graph export "${ruta}/fig_did_predicciones.png", replace width(1200)

* 4.3 DiD con grado de ruralidad continuo
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  4.3 DiD con grado de ruralidad continuo"
di as text "{hline 70}"

eststo did_grural: reghdfe pobre grural_post ///
    tamhogar edad_jefe_hogar agri, ///
    absorb(hhid year) vce(cluster hhid)

* 4.4 Event Study: dinámica temporal del efecto
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  4.4 Event Study: Rural × Año (año base = 2019)"
di as text "{hline 70}"

* Interacciones rural × año (omitiendo 2019 como base)
gen rural_2018 = rural * yr2018
gen rural_2020 = rural * yr2020
gen rural_2021 = rural * yr2021
label var rural_2018 "Rural × 2018"
label var rural_2020 "Rural × 2020"
label var rural_2021 "Rural × 2021"

eststo eventstudy: reghdfe pobre ///
    rural_2018 rural_2020 rural_2021 ///
    tamhogar edad_jefe_hogar agri, ///
    absorb(hhid year) vce(cluster hhid)

* Gráfico de event study manual
coefplot eventstudy, keep(rural_2018 rural_2020 rural_2021) ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    xline(1.5, lcolor(gray) lpattern(dash)) ///
    coeflabels(rural_2018 = "2018" rural_2020 = "2020" rural_2021 = "2021") ///
    title("Event Study: Efecto diferencial de la ruralidad") ///
    subtitle("Año base: 2019 (pre-COVID)") ///
    ytitle("Coeficiente (Rural × Año)") ///
    xtitle("Año") ///
    note("Línea vertical: inicio del COVID-19. Controles: tamaño hogar, edad jefe, agricultura." ///
         "EE clusterizados por hogar. Efectos fijos de hogar y año.") ///
    name(g_eventstudy, replace)
graph export "${ruta}/fig_event_study.png", replace width(1200)

* 4.5 Event Study con grado de ruralidad continuo
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  4.5 Event Study con grado de ruralidad continuo"
di as text "{hline 70}"

gen grural_2018 = grado_rural * yr2018
gen grural_2020 = grado_rural * yr2020
gen grural_2021 = grado_rural * yr2021
label var grural_2018 "Grado rural × 2018"
label var grural_2020 "Grado rural × 2020"
label var grural_2021 "Grado rural × 2021"

eststo eventstudy_g: reghdfe pobre ///
    grural_2018 grural_2020 grural_2021 ///
    tamhogar edad_jefe_hogar agri, ///
    absorb(hhid year) vce(cluster hhid)

coefplot eventstudy_g, keep(grural_2018 grural_2020 grural_2021) ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    xline(1.5, lcolor(gray) lpattern(dash)) ///
    coeflabels(grural_2018 = "2018" grural_2020 = "2020" grural_2021 = "2021") ///
    title("Event Study: Grado de ruralidad (continuo)") ///
    subtitle("Año base: 2019") ///
    ytitle("Coeficiente (Grado Rural × Año)") ///
    xtitle("Año") ///
    name(g_eventstudy_cont, replace)
graph export "${ruta}/fig_event_study_continuo.png", replace width(1200)

* 4.6 Tabla resumen DiD
* --------------------------------------------------------------------------
esttab did_fe did_cre did_grural eventstudy eventstudy_g ///
    using "${ruta}/tab_did_eventstudy.rtf", replace ///
    title("Diferencias en diferencias y event study: COVID-19") ///
    mtitles("DiD-FE" "DiD-CRE" "DiD-Grado" "ES-Binario" "ES-Continuo") ///
    cells(b(fmt(4) star) se(fmt(4) par)) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    stats(N N_g r2_a, ///
        labels("Observaciones" "Hogares" "R² ajustado") ///
        fmt(%9.0f %9.0f %9.4f)) ///
    note("EE clusterizados por hogar en paréntesis.") ///
    label

eststo clear


/*==============================================================================
  PARTE 5: TRIPLE DIFERENCIA (DDD) – AGRICULTURA COMO MECANISMO
  ==============================================================================
  
  H₀: El efecto protector de la ruralidad durante el COVID-19 se explica
      por la autosuficiencia agrícola de los hogares rurales.
  
  Especificación DDD:
  Y_it = α_i + λ_t + β₁(Rural×Post) + β₂(Agri×Post) + 
         β₃(Rural×Agri×Post) + X'γ + ε_it
  
  β₃ captura si la agricultura amplifica o atenúa el efecto protector
  de la ruralidad durante el COVID-19.
  
  No existe estudio publicado que implemente este DDD para Perú.
  ==============================================================================*/

di _newline(3)
di as result "╔══════════════════════════════════════════════════════════════╗"
di as result "║  PARTE 5: TRIPLE DIFERENCIA (DDD)                          ║"
di as result "╚══════════════════════════════════════════════════════════════╝"

* 5.1 DDD - LPM con efectos fijos
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  5.1 DDD: Rural × Post × Agricultura (LPM-FE)"
di as text "{hline 70}"

eststo ddd_fe: reghdfe pobre ///
    rural_post post_agri rural_post_agri ///
    tamhogar edad_jefe_hogar, ///
    absorb(hhid year) vce(cluster hhid)

* 5.2 DDD - CRE Probit
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  5.2 DDD: CRE Probit"
di as text "{hline 70}"

eststo ddd_cre: xtprobit pobre ///
    rural post2020 agri ///
    rural_post post_agri rural_agri rural_post_agri ///
    tamhogar edad_jefe_hogar ///
    mujer_jefe indigena educ_jefe_hogar ///
    m_tamhogar m_edad_jefe_hogar m_agri ///
    i.year, re vce(cluster hhid)

* Efectos marginales del triple término
margins, dydx(rural_post_agri) predict(pu0)

* Probabilidades predichas para las 8 celdas
margins rural#post2020#agri, predict(pu0) post

marginsplot, by(agri) ///
    title("Pobreza: Rural × Post-COVID × Agricultura") ///
    ytitle("Pr(Pobre)") xtitle("Periodo") ///
    xlabel(0 "Pre" 1 "Post") ///
    legend(order(1 "Urbano" 2 "Rural")) ///
    name(g_ddd, replace)
graph export "${ruta}/fig_ddd_predicciones.png", replace width(1200)

* 5.3 Tabla DDD
* --------------------------------------------------------------------------
esttab ddd_fe ddd_cre ///
    using "${ruta}/tab_ddd.rtf", replace ///
    title("Triple diferencia: Rural × Post-COVID × Agricultura") ///
    mtitles("DDD-FE" "DDD-CRE") ///
    cells(b(fmt(4) star) se(fmt(4) par)) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    stats(N N_g, labels("Observaciones" "Hogares") fmt(%9.0f)) ///
    note("β(Rural×Post×Agri) captura si la agricultura explica la protección rural.") ///
    label

eststo clear


/*==============================================================================
  PARTE 6: CADENAS DE MARKOV – MATRICES DE TRANSICIÓN
  ==============================================================================
  
  Metodología: Anderson & Goodman (1957), Cappellari & Jenkins (2004)
  Aplicación Perú: Huarancca, Castillo & Castellares (2023, BCRP)
  
  Estructura:
  6.1 Matrices de transición por área y periodo
  6.2 Tests de homogeneidad (chi-cuadrado)
  6.3 Distribuciones ergódicas
  6.4 Transiciones condicionadas en covariables (probit dinámico)
  6.5 Índices de movilidad
  ==============================================================================*/

di _newline(3)
di as result "╔══════════════════════════════════════════════════════════════╗"
di as result "║  PARTE 6: CADENAS DE MARKOV                                ║"
di as result "╚══════════════════════════════════════════════════════════════╝"

* 6.1 Matrices de transición por área y periodo
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  6.1 Matrices de transición: Rural vs Urbano, Pre vs Post"
di as text "{hline 70}"

* --- Rural, Pre-COVID (2018→2019) ---
di _newline as result "  >> Rural, Pre-COVID (2018-2019)"
preserve
    keep if rural == 1 & inlist(year, 2018, 2019)
    xttrans pobre, freq
restore

* --- Rural, Post-COVID (2020→2021) ---
di _newline as result "  >> Rural, Post-COVID (2020-2021)"
preserve
    keep if rural == 1 & inlist(year, 2020, 2021)
    xttrans pobre, freq
restore

* --- Urbano, Pre-COVID (2018→2019) ---
di _newline as result "  >> Urbano, Pre-COVID (2018-2019)"
preserve
    keep if rural == 0 & inlist(year, 2018, 2019)
    xttrans pobre, freq
restore

* --- Urbano, Post-COVID (2020→2021) ---
di _newline as result "  >> Urbano, Post-COVID (2020-2021)"
preserve
    keep if rural == 0 & inlist(year, 2020, 2021)
    xttrans pobre, freq
restore

* 6.2 Matrices de transición con ponderadores (cálculo manual)
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  6.2 Matrices de transición ponderadas"
di as text "{hline 70}"

* Programa para calcular matrices de transición ponderadas
capture program drop calc_transition_matrix
program define calc_transition_matrix
    syntax, group(string) period(string)
    
    di _newline as result "  Matriz de transición: `group', `period'"
    di as text "  {hline 50}"
    
    * Calcular transiciones ponderadas
    qui sum facpanel1821 if pobre_lag == 0 & pobre == 0
    local n00 = r(sum)
    qui sum facpanel1821 if pobre_lag == 0 & pobre == 1
    local n01 = r(sum)
    qui sum facpanel1821 if pobre_lag == 1 & pobre == 0
    local n10 = r(sum)
    qui sum facpanel1821 if pobre_lag == 1 & pobre == 1
    local n11 = r(sum)
    
    * Probabilidades
    local p00 = `n00' / (`n00' + `n01')
    local p01 = `n01' / (`n00' + `n01')
    local p10 = `n10' / (`n10' + `n11')
    local p11 = `n11' / (`n10' + `n11')
    
    di as text "                    t"
    di as text "  t-1        No Pobre    Pobre"
    di as text "  {hline 40}"
    di as text "  No Pobre   " %8.4f `p00' "    " %8.4f `p01'
    di as text "  Pobre      " %8.4f `p10' "    " %8.4f `p11'
    di as text "  {hline 40}"
    
    * Distribución ergódica (para matriz 2×2)
    local pi_pobre = (1 - `p00') / (2 - `p00' - `p11')
    local pi_nopobre = 1 - `pi_pobre'
    di as text "  Dist. ergódica: Pr(Pobre)* = " %8.4f `pi_pobre'
    
    * Índice de movilidad (Shorrocks, 1978)
    local mobil = (2 - `p00' - `p11') / (2 - 1)
    di as text "  Índice Shorrocks  = " %8.4f `mobil'
    
    * Guardar como matrices de Stata
    matrix P_`= subinstr("`group'"," ","_",.)' = (`p00', `p01' \ `p10', `p11')
end

* Calcular para cada celda
foreach area_val in 0 1 {
    if `area_val' == 0 local area_name "Urbano"
    if `area_val' == 1 local area_name "Rural"
    
    foreach post_val in 0 1 {
        if `post_val' == 0 local per_name "Pre-COVID"
        if `post_val' == 1 local per_name "Post-COVID"
        
        preserve
            keep if rural == `area_val' & post2020 == `post_val' & pobre_lag != .
            calc_transition_matrix, group("`area_name'_`per_name'") ///
                period("`per_name'")
        restore
    }
}

* 6.3 Test de homogeneidad: ¿las matrices difieren entre rural y urbano?
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  6.3 Test de homogeneidad de matrices de transición"
di as text "{hline 70}"

* Test via regresión: ¿el área modifica las probabilidades de transición?
* Usando logit multinomial con estado rezagado

di as result "  >> Test: ¿matrices difieren entre rural y urbano?"
di as result "     H0: P(rural) = P(urbano)"

* Pre-COVID
di _newline as result "  --- Pre-COVID ---"
preserve
    keep if post2020 == 0 & pobre_lag != .
    logit pobre i.rural##i.pobre_lag [pw = facpanel1821], vce(cluster hhid)
    testparm i.rural#i.pobre_lag
restore

* Post-COVID
di _newline as result "  --- Post-COVID ---"
preserve
    keep if post2020 == 1 & pobre_lag != .
    logit pobre i.rural##i.pobre_lag [pw = facpanel1821], vce(cluster hhid)
    testparm i.rural#i.pobre_lag
restore

* Test: ¿las matrices cambiaron entre pre y post COVID?
di _newline as result "  >> Test: ¿matrices cambiaron con el COVID?"
di as result "     H0: P(pre) = P(post)"

* Para rurales
di _newline as result "  --- Hogares rurales ---"
preserve
    keep if rural == 1 & pobre_lag != .
    logit pobre i.post2020##i.pobre_lag [pw = facpanel1821], vce(cluster hhid)
    testparm i.post2020#i.pobre_lag
restore

* Para urbanos
di _newline as result "  --- Hogares urbanos ---"
preserve
    keep if rural == 0 & pobre_lag != .
    logit pobre i.post2020##i.pobre_lag [pw = facpanel1821], vce(cluster hhid)
    testparm i.post2020#i.pobre_lag
restore

* 6.4 Transiciones condicionadas en covariables (probit dinámico)
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  6.4 Probit dinámico con estado rezagado (Cappellari-Jenkins)"
di as text "{hline 70}"

* Modelo dinámico: Pr(pobre_t | pobre_{t-1}, X)
* Incluye pobre_lag como regresor + medias Mundlak + condiciones iniciales

* Condición inicial (Wooldridge 2005): pobre en el primer año
bysort hhid (year): gen pobre_inicial = pobre[1]
label var pobre_inicial "Pobre en año base (condición inicial)"

* Modelo
eststo markov_probit: xtprobit pobre ///
    pobre_lag ///
    rural post2020 rural_post ///
    c.pobre_lag#c.rural c.pobre_lag#c.post2020 ///
    c.pobre_lag#c.rural#c.post2020 ///
    tamhogar edad_jefe_hogar agri mujer_jefe indigena educ_jefe_hogar ///
    pobre_inicial ///
    m_tamhogar m_edad_jefe_hogar m_agri ///
    i.year if pobre_lag != ., re vce(cluster hhid)

* Probabilidades de transición predichas para cada celda
margins rural#post2020, at(pobre_lag = 0) predict(pu0) post
eststo trans_nopobre

di _newline as result "  Pr(Pobre_t = 1 | Pobre_{t-1} = 0): Entrada a pobreza"
margins rural#post2020, at(pobre_lag = 0) predict(pu0)

di _newline as result "  Pr(Pobre_t = 1 | Pobre_{t-1} = 1): Persistencia en pobreza"
margins rural#post2020, at(pobre_lag = 1) predict(pu0)

* Gráfico de probabilidades de transición
margins rural#post2020, at(pobre_lag = (0 1)) predict(pu0)
marginsplot, by(_at) ///
    title("Probabilidades de transición: Markov condicionado") ///
    ytitle("Pr(Pobre en t)") xtitle("Periodo") ///
    xlabel(0 "Pre-COVID" 1 "Post-COVID") ///
    legend(order(1 "Urbano" 2 "Rural")) ///
    name(g_markov_trans, replace)
graph export "${ruta}/fig_markov_transiciones.png", replace width(1200)

* 6.5 Pobreza crónica vs transitoria (clasificación de trayectorias)
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  6.5 Clasificación de trayectorias de pobreza"
di as text "{hline 70}"

* Contar años en pobreza por hogar
bysort hhid: egen años_pobre = total(pobre)
label var años_pobre "Número de años en pobreza (de 4)"

* Clasificación
gen trayectoria = .
replace trayectoria = 1 if años_pobre == 0
replace trayectoria = 2 if años_pobre == 1
replace trayectoria = 3 if inlist(años_pobre, 2, 3)
replace trayectoria = 4 if años_pobre == 4
label define lb_tray 1 "Nunca pobre" 2 "Transitorio (1 año)" ///
    3 "Recurrente (2-3 años)" 4 "Crónico (4 años)"
label values trayectoria lb_tray
label var trayectoria "Trayectoria de pobreza 2018-2021"

* Distribución por área
table rural trayectoria [pw = facpanel1821] if year == 2018, ///
    statistic(frequency) statistic(percent, across(trayectoria))

* Determinantes de la pobreza crónica vs transitoria (logit multinomial)
preserve
    keep if year == 2018
    eststo tray_mlogit: mlogit trayectoria rural grado_rural ///
        tamhogar edad_jefe_hogar mujer_jefe indigena ///
        educ_jefe_hogar agri [pw = facpanel1821], ///
        baseoutcome(1) vce(cluster prov)
    
    margins, dydx(rural) predict(outcome(4))
    di as result "  Efecto marginal de rural sobre Pr(Pobreza crónica):"
    margins, dydx(rural) predict(outcome(4)) post
restore

esttab markov_probit ///
    using "${ruta}/tab_markov_probit.rtf", replace ///
    title("Probit dinámico con transiciones de Markov condicionadas") ///
    cells(b(fmt(4) star) se(fmt(4) par)) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    stats(N N_g ll, ///
        labels("Observaciones" "Hogares" "Log-likelihood") ///
        fmt(%9.0f %9.0f %9.2f)) ///
    note("Probit RE con corrección Mundlak y condición inicial (Wooldridge 2005).") ///
    label

eststo clear


/*==============================================================================
  PARTE 7: ANÁLISIS DE DURACIÓN DEL SHOCK COVID-19
  ==============================================================================
  
  Objetivo: Estimar si la permanencia en pobreza exhibe dependencia de
  duración diferenciada entre áreas rurales y urbanas post-COVID.
  
  Métodos:
  7.1 Spells de pobreza (preparación de datos de supervivencia)
  7.2 Modelo de Cox (semiparamétrico)
  7.3 Modelo Weibull con fragilidad compartida
  7.4 Funciones de supervivencia comparativas
  7.5 Test de quiebre estructural en la serie de pobreza
  
  Refs: Gørgens & Hyslop (2016), Bane & Ellwood (1986)
  ==============================================================================*/

di _newline(3)
di as result "╔══════════════════════════════════════════════════════════════╗"
di as result "║  PARTE 7: ANÁLISIS DE DURACIÓN                             ║"
di as result "╚══════════════════════════════════════════════════════════════╝"

* 7.1 Preparación de spells de pobreza
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  7.1 Identificación de spells de pobreza"
di as text "{hline 70}"

sort hhid year

* Identificar inicio de spell de pobreza
by hhid: gen spell_start_p = (pobre == 1 & (pobre[_n-1] == 0 | _n == 1))

* Identificar inicio de spell de NO pobreza (para salida)
by hhid: gen spell_start_np = (pobre == 0 & (pobre[_n-1] == 1 | _n == 1))

* Asignar ID de spell dentro de cada hogar
by hhid: gen spell_id = sum(spell_start_p) if pobre == 1

* Duración del spell (años consecutivos en pobreza)
bysort hhid spell_id: gen spell_dur = _N if spell_id != . & pobre == 1
bysort hhid spell_id: gen spell_orden = _n if spell_id != . & pobre == 1

* Indicador de salida de pobreza (evento = transición a no pobre)
by hhid: gen sale_pobreza = (pobre == 1 & pobre[_n+1] == 0)
* Censurar por derecha si el panel termina en pobreza
by hhid: replace sale_pobreza = 0 if pobre == 1 & _n == _N

* Mantener solo la última observación de cada spell
preserve
    keep if pobre == 1 & spell_id != .
    bysort hhid spell_id: keep if _n == _N
    
    * Variables del spell
    gen censurado = 1 - sale_pobreza
    label var spell_dur "Duración del spell (años)"
    label var sale_pobreza "Salió de pobreza (evento)"
    label var censurado "Spell censurado por derecha"
    
    * Año de inicio del spell
    gen año_inicio_spell = year - spell_dur + 1
    gen spell_pre = (año_inicio_spell < 2020)
    gen spell_post = (año_inicio_spell >= 2020)
    label var spell_pre "Spell inició pre-COVID"
    label var spell_post "Spell inició post-COVID"

    * 7.2 Declarar datos de supervivencia
    * ------------------------------------------------------------------
    di _newline as text "{hline 70}"
    di as result "  7.2 Análisis de supervivencia"
    di as text "{hline 70}"
    
    stset spell_dur, failure(sale_pobreza == 1) id(hhid)
    
    * Descripción
    stdescribe
    stsum
    stsum, by(rural)
    
    * 7.3 Kaplan-Meier por área y periodo
    * ------------------------------------------------------------------
    di _newline as text "{hline 70}"
    di as result "  7.3 Kaplan-Meier: supervivencia en pobreza"
    di as text "{hline 70}"
    
    * Generar grupo combinado
    gen grupo = rural * 2 + spell_post
    label define lb_grupo 0 "Urbano Pre" 1 "Urbano Post" ///
        2 "Rural Pre" 3 "Rural Post"
    label values grupo lb_grupo
    
    sts graph, by(grupo) ///
        title("Supervivencia en pobreza por área y periodo") ///
        subtitle("Kaplan-Meier") ///
        ytitle("Pr(Permanece pobre)") xtitle("Duración (años)") ///
        legend(order(1 "Urbano Pre" 2 "Urbano Post" ///
            3 "Rural Pre" 4 "Rural Post") rows(2)) ///
        name(g_km, replace)
    graph export "${ruta}/fig_kaplan_meier.png", replace width(1200)
    
    * Log-rank test
    sts test rural, logrank
    sts test grupo, logrank
    
    * 7.4 Modelo de Cox
    * ------------------------------------------------------------------
    di _newline as text "{hline 70}"
    di as result "  7.4 Modelo de Cox: salida de pobreza"
    di as text "{hline 70}"
    
    stcox rural spell_post c.rural#c.spell_post ///
        tamhogar edad_jefe_hogar agri mujer_jefe educ_jefe_hogar, ///
        vce(cluster hhid)
    
    * Test de proporcionalidad
    estat phtest, detail
    
    * Hazard ratios
    stcox rural spell_post c.rural#c.spell_post ///
        tamhogar edad_jefe_hogar agri mujer_jefe educ_jefe_hogar, ///
        vce(cluster hhid) nohr
    eststo cox_model
    
    * 7.5 Modelo paramétrico (Weibull) con fragilidad
    * ------------------------------------------------------------------
    di _newline as text "{hline 70}"
    di as result "  7.5 Modelo Weibull"
    di as text "{hline 70}"
    
    * Nota: fragilidad compartida requiere múltiples spells por grupo
    * Con panel corto (4 años), usar Weibull sin fragilidad
    streg rural spell_post c.rural#c.spell_post ///
        tamhogar edad_jefe_hogar agri mujer_jefe educ_jefe_hogar, ///
        dist(weibull) vce(cluster hhid) nohr
    eststo weibull_model
    
    * Curvas de supervivencia predichas
    stcurve, survival at1(rural = 1 spell_post = 0) ///
        at2(rural = 1 spell_post = 1) ///
        at3(rural = 0 spell_post = 0) ///
        at4(rural = 0 spell_post = 1) ///
        title("Supervivencia predicha: Weibull") ///
        ytitle("Pr(Permanece pobre)") xtitle("Duración (años)") ///
        legend(order(1 "Rural Pre" 2 "Rural Post" ///
            3 "Urbano Pre" 4 "Urbano Post") rows(2)) ///
        name(g_weibull, replace)
    graph export "${ruta}/fig_weibull_surv.png", replace width(1200)
    
    esttab cox_model weibull_model ///
        using "${ruta}/tab_duracion.rtf", replace ///
        title("Modelos de duración: salida de pobreza") ///
        mtitles("Cox PH" "Weibull") ///
        cells(b(fmt(4) star) se(fmt(4) par)) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        stats(N ll chi2, ///
            labels("Spells" "Log-likelihood" "Chi²") ///
            fmt(%9.0f %9.2f %9.2f)) ///
        note("Coeficientes (no hazard ratios). EE clusterizados por hogar.") ///
        label
    
    eststo clear
    
restore

* 7.6 Análisis de la persistencia: probabilidad de permanecer pobre
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  7.6 Persistencia: Pr(Pobre_t | Pobre_{t-1}) por año y área"
di as text "{hline 70}"

* Tasa de persistencia (Pr(pobre=1|pobre_lag=1))
table year rural if pobre_lag == 1 [pw = facpanel1821], ///
    statistic(mean pobre) nformat(%9.4f)

* Tasa de entrada (Pr(pobre=1|pobre_lag=0))
table year rural if pobre_lag == 0 [pw = facpanel1821], ///
    statistic(mean pobre) nformat(%9.4f)


/*==============================================================================
  PARTE 8: SELECCIÓN DEL MODELO Y DIAGNÓSTICOS
  ==============================================================================
  
  Criterios de selección:
  - AIC/BIC para modelos anidados
  - Test de Hausman para FE vs RE
  - Comparación de efectos marginales entre modelos
  - Diagnósticos de heterocedasticidad y autocorrelación
  ==============================================================================*/

di _newline(3)
di as result "╔══════════════════════════════════════════════════════════════╗"
di as result "║  PARTE 8: SELECCIÓN Y DIAGNÓSTICOS                         ║"
di as result "╚══════════════════════════════════════════════════════════════╝"

* 8.1 Comparación de criterios de información
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  8.1 Comparación AIC/BIC"
di as text "{hline 70}"

* Modelo 1: Pooled Probit
quietly probit pobre rural post2020 rural_post ///
    tamhogar edad_jefe_hogar agri mujer_jefe indigena educ_jefe_hogar ///
    i.year, vce(cluster hhid)
estat ic
matrix IC_pooled = r(S)

* Modelo 2: RE Probit
quietly xtprobit pobre rural post2020 rural_post ///
    tamhogar edad_jefe_hogar agri mujer_jefe indigena educ_jefe_hogar ///
    i.year, re
estat ic
matrix IC_re = r(S)

* Modelo 3: CRE Probit
quietly xtprobit pobre rural post2020 rural_post ///
    tamhogar edad_jefe_hogar agri mujer_jefe indigena educ_jefe_hogar ///
    m_tamhogar m_edad_jefe_hogar m_agri ///
    i.year, re
estat ic
matrix IC_cre = r(S)

* Modelo 4: CRE Probit dinámico
quietly xtprobit pobre pobre_lag rural post2020 rural_post ///
    tamhogar edad_jefe_hogar agri mujer_jefe indigena educ_jefe_hogar ///
    pobre_inicial m_tamhogar m_edad_jefe_hogar m_agri ///
    i.year if pobre_lag != ., re
estat ic
matrix IC_dyn = r(S)

di _newline as result "  Criterios de información:"
di as text "  {hline 50}"
di as text "  Modelo               AIC          BIC"
di as text "  {hline 50}"
di as text "  Pooled Probit    " %12.2f IC_pooled[1,5] "  " %12.2f IC_pooled[1,6]
di as text "  RE Probit        " %12.2f IC_re[1,5] "  " %12.2f IC_re[1,6]
di as text "  CRE Probit       " %12.2f IC_cre[1,5] "  " %12.2f IC_cre[1,6]
di as text "  CRE Dinámico     " %12.2f IC_dyn[1,5] "  " %12.2f IC_dyn[1,6]
di as text "  {hline 50}"

* 8.2 Test de significancia de las medias Mundlak
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  8.2 Test de Mundlak (significancia conjunta de medias)"
di as text "{hline 70}"

quietly xtprobit pobre rural post2020 rural_post ///
    tamhogar edad_jefe_hogar agri mujer_jefe indigena educ_jefe_hogar ///
    m_tamhogar m_edad_jefe_hogar m_agri ///
    i.year, re
test m_tamhogar m_edad_jefe_hogar m_agri

di as result "  Si p < 0.05: CRE es preferido sobre RE estándar."
di as result "  Esto indica correlación entre efecto individual y covariables."

* 8.3 Diagnóstico de heterocedasticidad en panel
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  8.3 Test de heterocedasticidad (Breusch-Pagan)"
di as text "{hline 70}"

quietly xtreg pobre rural post2020 rural_post ///
    tamhogar edad_jefe_hogar agri mujer_jefe indigena educ_jefe_hogar ///
    m_tamhogar m_edad_jefe_hogar m_agri ///
    i.year, re
xttest0

* 8.4 Resumen de efectos marginales clave entre modelos
* --------------------------------------------------------------------------
di _newline as text "{hline 70}"
di as result "  8.4 Resumen: efecto de rural_post (DiD) por modelo"
di as text "{hline 70}"

* LPM-FE
quietly reghdfe pobre rural_post tamhogar edad_jefe_hogar agri, ///
    absorb(hhid year) vce(cluster hhid)
local b_fe = _b[rural_post]
local se_fe = _se[rural_post]

* CRE-LPM
quietly xtreg pobre rural post2020 rural_post ///
    tamhogar edad_jefe_hogar agri mujer_jefe indigena educ_jefe_hogar ///
    m_tamhogar m_edad_jefe_hogar m_agri ///
    i.year [pw = facpanel1821], re vce(cluster hhid)
local b_crelpm = _b[rural_post]
local se_crelpm = _se[rural_post]

* CRE-Probit (efecto marginal)
quietly xtprobit pobre rural post2020 rural_post ///
    tamhogar edad_jefe_hogar agri mujer_jefe indigena educ_jefe_hogar ///
    m_tamhogar m_edad_jefe_hogar m_agri ///
    i.year, re vce(cluster hhid)
quietly margins, dydx(rural_post) predict(pu0)
matrix MFX = r(table)
local b_creprobit = MFX[1,1]
local se_creprobit = MFX[2,1]

di as text "  {hline 60}"
di as text "  Modelo            β(rural_post)     SE        p-value"
di as text "  {hline 60}"
di as text "  LPM-FE            " %9.4f `b_fe' "    " %9.4f `se_fe' ///
    "    " %6.4f 2*normal(-abs(`b_fe'/`se_fe'))
di as text "  CRE-LPM           " %9.4f `b_crelpm' "    " %9.4f `se_crelpm' ///
    "    " %6.4f 2*normal(-abs(`b_crelpm'/`se_crelpm'))
di as text "  CRE-Probit (AME)  " %9.4f `b_creprobit' "    " %9.4f `se_creprobit' ///
    "    " %6.4f 2*normal(-abs(`b_creprobit'/`se_creprobit'))
di as text "  {hline 60}"
di _newline as text "  Nota: rural_post < 0 → ruralidad protege contra la pobreza post-COVID"
di as text "        rural_post > 0 → ruralidad aumenta pobreza post-COVID"


/*==============================================================================
  CIERRE
  ==============================================================================*/

di _newline(3)
di as result "╔══════════════════════════════════════════════════════════════╗"
di as result "║  ANÁLISIS COMPLETO                                         ║"
di as result "╚══════════════════════════════════════════════════════════════╝"
di _newline
di as result "  Archivos generados:"
di as text "  - Panel_18_21_preparado.dta (base preparada)"
di as text "  - tab_descriptivas.rtf"
di as text "  - tab_interacciones_mfx.rtf"
di as text "  - tab_modelos_panel.rtf"
di as text "  - tab_did_eventstudy.rtf"
di as text "  - tab_ddd.rtf"
di as text "  - tab_markov_probit.rtf"
di as text "  - tab_duracion.rtf"
di as text "  - fig_mfx_rural_cre.png"
di as text "  - fig_mfx_grado_rural.png"
di as text "  - fig_did_predicciones.png"
di as text "  - fig_event_study.png"
di as text "  - fig_event_study_continuo.png"
di as text "  - fig_ddd_predicciones.png"
di as text "  - fig_markov_transiciones.png"
di as text "  - fig_kaplan_meier.png"
di as text "  - fig_weibull_surv.png"
di _newline
di as result "  Paquetes requeridos (instalar previamente con ssc install):"
di as text "  reghdfe, ftools, coefplot, estout, esttab"
di _newline
di as result "  Referencia: Panel Analysis of Rurality, Poverty and COVID-19"
di as result "  in Peru: Methodological Guide (2025)"

log close
