rm(list=ls())

##################################################################################

library(stats)
library(haven)
library(ggplot2)
library(markovchain)
library(dynlm)
library(dplyr)
library(expm)
library(ggpubr)
library(data.table)
library(openxlsx)
library(forecast)
library(Metrics)
library(yardstick)
library(car)
library(multcomp)

setwd(r"(C:\Users\User\Documents\Trabajo\Banco Mundial\Perú\Proyectos\Migración\temp)")

#SE IMPORTA LA DATA 
rm(list=ls())
data_base <- read_dta("Panel_19_22_Reg.dta")

summary(data_base)

data_base <- data_base %>%
  arrange(numpanh, year) %>%
  # Agrupar por el identificador del hogar
  group_by(numpanh) %>%
  # Rezago de pobreza
  mutate(pobre_lag = lag(pobre, 1)) %>%
  # Desagrupar para futuras operaciones
  ungroup()

data_base <- data_base %>%
  mutate(
    tratamiento = as.factor(tratamiento),
    numpanh = as.factor(numpanh),
    year = as.factor(year), # Tratamos year como efectos fijos de tiempo
    pobre = as.numeric(pobre) # Aseguramos que la dependiente sea 0/1
  )

modelo_logit <- glm(pobre ~ (tratamiento + edad_jefe_hogar + sexo_jefe_hogar +
                    raza_jefe_hogar + accidente_jefe_hogar + educ_jefe_hogar + leer_jefe_hogar +
                    trabajo_jefe_hogar + limit_jefe_hogar + mov_hijo)*pobre_lag,
                    data = data_base,
                    family = binomial(link = "logit"))

# Resumen de los resultados
summary(modelo_logit)
