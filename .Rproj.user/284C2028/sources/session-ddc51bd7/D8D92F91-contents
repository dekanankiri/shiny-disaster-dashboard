# ===================================================================
# global.R
#
# This script loads all necessary libraries, reads data from files,
# and performs initial data pre-processing. The objects created here
# are available globally to both ui.R and server.R.
# ===================================================================

# -- Load Libraries --
library(shiny)
library(shinydashboard)
library(leaflet)
library(tidyverse)
library(plotly)
library(readxl)
library(forecast)
library(ggfortify)
library(sf)
library(lubridate) # Added for year() and month() functions

# ngetes push pull github

# -- Load and Process Data --

# Load primary datasets
full_data <- read_excel("data/DataKomstat_Gabung.xlsx", sheet = "komstat")
data_prov <- read_excel("data/DataKomstat_Provinsi.xlsx")

# Ensure numeric columns are correctly typed
numeric_cols <- c("Bencana_jumlah", "Meninggal", "Hilang", "Terendam", "Mengungsi", 
                  "Rusak Berat", "Rusak Sedang", "Rusak Ringan", "Curah_hujan", "Temp_mean")
full_data[numeric_cols] <- lapply(full_data[numeric_cols], function(x) as.numeric(as.character(x)))

# Load and prepare GeoJSON data for the interactive map
prov_geo <- st_read("www/indonesia-prov.geojson", quiet = TRUE)
prov_geo$Propinsi <- toupper(trimws(prov_geo$Propinsi)) # Standardize province names

# Prepare provincial data for joining with GeoJSON
data_prov$NAME_1 <- toupper(trimws(data_prov$Wilayah))
data_prov$`Jumlah Kejadian` <- as.numeric(gsub(",", "", data_prov$`Jumlah Kejadian`))

# Add dummy coordinates (as in the original script)
# Note: For a real application, you would use actual coordinates.
set.seed(123)
full_data$latitude <- runif(nrow(full_data), -10, 5)
full_data$longitude <- runif(nrow(full_data), 95, 141)

# Create a list of province choices for the sidebar dropdown
# This is defined globally so it doesn't need to be recalculated.
provinsi_choices <- c("SEMUA PROVINSI", unique(full_data$Provinsi))