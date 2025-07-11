# data_prep.R - Skrip untuk mempersiapkan data sekali saja

# 1. Muat pustaka yang diperlukan
library(readxl)
library(sf)
library(dplyr)
library(stringr)

# 2. Muat semua data mentah
message("Memuat file Excel dan GeoJSON...")
full_data <- read_excel("data/DataKomstat_Gabung.xlsx")
data_prov <- read_excel("data/DataKomstat_Provinsi.xlsx")
prov_geo <- st_read("www/indonesia-prov.geojson", quiet = TRUE)
message("Data mentah berhasil dimuat.")

# 3. Lakukan semua pembersihan dan transformasi data di sini
message("Melakukan pembersihan data...")

# Membersihkan full_data
numeric_cols <- c("Bencana_jumlah", "Meninggal", "Hilang", "Terendam", "Mengungsi", "Rusak Berat", "Rusak Sedang", "Rusak Ringan", "Curah_hujan", "Temp_mean")
existing_cols <- numeric_cols[numeric_cols %in% names(full_data)]
if(length(existing_cols) > 0) {
  full_data[existing_cols] <- lapply(full_data[existing_cols], function(x) as.numeric(as.character(x)))
}

# Membersihkan data_prov
prov_col_name <- if("Wilayah" %in% names(data_prov)) "Wilayah" else names(data_prov)[2]
data_prov$NAME_1 <- toupper(trimws(data_prov[[prov_col_name]]))
data_prov$`Jumlah Kejadian` <- as.numeric(gsub(",", "", data_prov$`Jumlah Kejadian`))

# Membersihkan prov_geo
if(nrow(prov_geo) > 0 && "Propinsi" %in% names(prov_geo)) {
  prov_geo$Propinsi <- toupper(trimws(prov_geo$Propinsi))
}
message("Pembersihan data selesai.")

# 4. Simpan objek yang sudah bersih ke dalam satu file .RData
# File ini akan dimuat dengan sangat cepat oleh aplikasi Shiny Anda.
save(full_data, data_prov, prov_geo, file = "data/disaster_data_clean.RData")

message("Data yang sudah diproses disimpan ke data/disaster_data_clean.RData. Anda siap untuk deploy!")