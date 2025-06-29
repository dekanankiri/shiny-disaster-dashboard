library(shiny)
library(shinydashboard)
library(leaflet)
library(tidyverse)
library(plotly)
library(readxl)
library(forecast)
library(ggfortify)

# Load data
full_data <- read_excel("data/DataKomstat_Gabung.xlsx", sheet = "komstat")

# Pastikan kolom numerik valid
full_data[c("Bencana_jumlah", "Meninggal", "Hilang", "Terendam", "Mengungsi", 
            "Rusak Berat", "Rusak Sedang", "Rusak Ringan", "Curah_hujan", "Temp_mean")] <- 
  lapply(full_data[c("Bencana_jumlah", "Meninggal", "Hilang", "Terendam", "Mengungsi", 
                     "Rusak Berat", "Rusak Sedang", "Rusak Ringan", "Curah_hujan", "Temp_mean")], 
         function(x) as.numeric(as.character(x)))

# Tambahkan kolom koordinat dummy (jika belum tersedia dalam dataset)
set.seed(123)
full_data$latitude <- runif(nrow(full_data), -10, 5)
full_data$longitude <- runif(nrow(full_data), 95, 141)