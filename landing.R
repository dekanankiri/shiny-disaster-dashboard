# --- 1. MEMUAT PUSTAKA YANG DIPERLUKAN ---
# Pastikan semua pustaka ini sudah terinstal: install.packages(c("shiny", "shinydashboard", ...))
library(shiny)
library(shinydashboard)
library(shinyjs)
library(leaflet)
library(tidyverse)
library(plotly)
library(readxl)
library(forecast)
library(ggfortify)
library(sf)
library(shinycssloaders) # Untuk indikator loading
library(DT)              # Untuk tabel interaktif
library(markdown)        # Diperlukan untuk renderMarkdown

# --- 2. MEMUAT DAN MEMPERSIAPKAN DATA ---
# Catatan: Pastikan file data berada di direktori yang benar
# Membaca data dari file Excel.
tryCatch({
  full_data <- read_excel("data/DataKomstat_Gabung.xlsx")
  data_prov <- read_excel("data/DataKomstat_Provinsi.xlsx")
  message("Berhasil memuat file data Excel.")
}, error = function(e) {
  # Membuat data dummy jika file tidak ada untuk memastikan aplikasi tetap berjalan
  message("File data Excel tidak ditemukan. Menggunakan data dummy sebagai gantinya.")
  message("Error: ", e$message)
  full_data <- tibble(
    Year = rep(2010:2023, each = 12 * 5),
    Month = rep(1:12, times = 14 * 5),
    Provinsi = rep(paste("PROVINSI", LETTERS[1:5]), each = 14 * 12),
    Bencana_jenis = sample(c("Banjir", "Tanah Longsor", "Kekeringan", "Gempa Bumi"), 14 * 12 * 5, replace = TRUE),
    Bencana_jumlah = rpois(14 * 12 * 5, 5),
    Meninggal = rpois(14 * 12 * 5, 2),
    Hilang = rpois(14 * 12 * 5, 1),
    Terendam = rpois(14 * 12 * 5, 10),
    Mengungsi = rpois(14 * 12 * 5, 50),
    `Rusak Berat` = rpois(14 * 12 * 5, 3),
    `Rusak Sedang` = rpois(14 * 12 * 5, 5),
    `Rusak Ringan` = rpois(14 * 12 * 5, 10),
    Curah_hujan = rnorm(14 * 12 * 5, 150, 50),
    Temp_mean = rnorm(14 * 12 * 5, 27, 2)
  )
  data_prov <- full_data %>%
    group_by(Tahun = Year, Wilayah = Provinsi) %>%
    summarise(`Jumlah Kejadian` = sum(Bencana_jumlah, na.rm = TRUE), .groups = 'drop')
})

# Pastikan kolom numerik valid
numeric_cols <- c("Bencana_jumlah", "Meninggal", "Hilang", "Terendam", "Mengungsi", "Rusak Berat", "Rusak Sedang", "Rusak Ringan", "Curah_hujan", "Temp_mean")
# Periksa kolom mana yang ada sebelum mencoba mengubahnya
existing_cols <- numeric_cols[numeric_cols %in% names(full_data)]
full_data[existing_cols] <- lapply(full_data[existing_cols], function(x) as.numeric(as.character(x)))


# GeoJSON untuk provinsi Indonesia (gunakan data dummy jika file tidak ada)
tryCatch({
  prov_geo <- st_read("www/indonesia-prov.geojson", quiet = TRUE)
}, error = function(e) {
  message("File GeoJSON tidak ditemukan. Peta tidak akan ditampilkan dengan benar.")
  prov_geo <- st_sf(st_sfc(), crs = 4326) # Membuat objek sf kosong
})


# Siapkan data provinsi dan samakan nama
prov_col_name <- if("Wilayah" %in% names(data_prov)) "Wilayah" else names(data_prov)[2] # Asumsi kolom kedua adalah nama provinsi
data_prov$NAME_1 <- toupper(trimws(data_prov[[prov_col_name]]))
data_prov$`Jumlah Kejadian` <- as.numeric(gsub(",", "", data_prov$`Jumlah Kejadian`))

# Standarisasi nama kolom GeoJSON
if(nrow(prov_geo) > 0 && "Propinsi" %in% names(prov_geo)) {
  prov_geo$Propinsi <- toupper(trimws(prov_geo$Propinsi))
}

# --- 3. UI (ANTARMUKA PENGGUNA) YANG DIMODIFIKASI ---
ui <- dashboardPage(
  # Header
  dashboardHeader(
    title = HTML('<img src="logo.png" height="35" style="margin-right: 10px; vertical-align: middle;"> Dashboard Bencana & Iklim'),
    titleWidth = 350
  ),
  
  # Sidebar
  dashboardSidebar(
    collapsed = TRUE,
    sidebarMenu(id = "tabs",
                # Menu untuk Landing Page
                menuItem("Selamat Datang", tabName = "landing_page", icon = icon("door-open")),
                
                # Menu Analisis
                menuItem("Ringkasan", tabName = "ringkasan", icon = icon("tachometer-alt")),
                menuItem("Peta Interaktif", tabName = "peta", icon = icon("map-marked-alt")),
                menuItem("Analisis Iklim", tabName = "iklim", icon = icon("cloud-sun-rain")),
                menuItem("Analisis Statistik", tabName = "statistik", icon = icon("chart-line")),
                menuItem("Forecasting", tabName = "forecast", icon = icon("clock")),
                menuItem("Data Explorer", tabName = "data_explorer", icon = icon("table")),
                
                # Menu Informasi
                menuItem("Panduan Pengguna", tabName = "user_guide", icon = icon("book-reader")),
                menuItem("Metadata", tabName = "metadata", icon = icon("database")),
                menuItem("Tentang", tabName = "tentang", icon = icon("info-circle"))
    )
  ),
  
  # Body
  dashboardBody(
    shinyjs::useShinyjs(),
    # --- CSS Kustom untuk Tampilan ---
    tags$head(
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1.0"),
      tags$style(HTML('
        /* --- CSS UNTUK LANDING PAGE --- */
        .main-header .logo {
          padding: 0 15px !important;
          height: 50px !important;
        }
        
        .main-header .logo img {
          vertical-align: middle;
          max-height: 40px;
          width: auto;
        }
        
        /* Responsive logo */
        @media (max-width: 768px) {
          .main-header .logo img {
            max-height: 30px;
          }
          .main-header .logo span {
            font-size: 16px !important;
          }
        }
        .landing-page-content {
            padding-top: 20px;
            padding-bottom: 40px;
        }
        .landing-page-content h1 {
            font-family: "Oswald", sans-serif;
            font-size: 42px;
            font-weight: 700;
            color: #4a312f;
        }
        .landing-page-content .lead {
            font-size: 18px;
            color: #614a48;
            max-width: 800px;
            margin-left: auto;
            margin-right: auto;
        }
        .landing-page-content .btn-start {
             background: linear-gradient(90deg, #FF8C00, #FF4500);
             color: white;
             border: none;
             font-weight: bold;
             padding: 15px 30px;
             font-size: 20px;
             transition: transform 0.3s ease, box-shadow 0.3s ease;
             border-radius: 5px;
        }
        .landing-page-content .btn-start:hover {
            transform: translateY(-3px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.2);
        }
        .feature-box {
            padding-bottom: 20px;
        }
        .feature-box .fa-3x {
            color: #FF4500;
        }
        
      /* --- FONT BARU --- */
      @import url("https://fonts.googleapis.com/css2?family=Oswald:wght@400;700&family=Roboto:wght@400;700&display=swap");

      /* Font utama */
      body, label, input, button, select, .box-title, .main-header .logo { 
        font-family: "Roboto", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
      }
      
      /* --- FONT JUDUL TAB BARU --- */
      .content-wrapper h2 {
        font-family: "Oswald", sans-serif;
        font-weight: 400;
        color: #4a312f; /* Warna coklat tua dari sidebar */
        text-transform: uppercase;
        letter-spacing: 1px;
        border-bottom: 2px solid #FF8C00;
        padding-bottom: 10px;
        margin-top: 10px;
        margin-bottom: 20px;
      }
      
      /* Skema Warna Gradasi Oranye-Merah */
      .skin-blue .main-header .navbar, .skin-blue .main-header .logo {
        background: linear-gradient(90deg, #FF8C00, #FF4500) !important;
      }
      
      .skin-blue .main-sidebar { 
        background-color: #4a312f !important; /* Warna merah-coklat tua */
      }

      /* --- PERUBAHAN LATAR BELAKANG --- */
      .content-wrapper, .right-side { 
        background-color: #fffaf0 !important; /* Warna Krem Baru */
        min-height: 100vh; /* Memastikan tinggi minimum adalah tinggi layar */
      }

      /* --- ANIMASI SIDEBAR MENU --- */
      .skin-blue .sidebar-menu > li > a {
        transition: background-color 0.3s ease, padding-left 0.3s ease;
      }
      .skin-blue .sidebar-menu > li.active > a, 
      .skin-blue .sidebar-menu > li:hover > a {
        background-color: #614a48 !important; /* Warna yang sama dengan input select */
        border-left-color: #ff6347 !important; /* Tomato Red */
        padding-left: 20px !important; /* Efek indent saat hover */
      }

      /* --- ANIMASI HOVER UNTUK BOX --- */
      .box {
        border-radius: 5px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.07);
        border-top-width: 3px;
        transition: transform 0.3s ease, box-shadow 0.3s ease !important;
      }
      .box:hover {
        transform: translateY(-5px);
        box-shadow: 0 12px 24px rgba(0,0,0,0.15) !important;
      }
      
      /* Warna border-top untuk box primer dan info */
      .box.box-primary { border-top-color: #FF4500 !important; }
      .box.box-info { border-top-color: #FF8C00 !important; }

      /* CSS BARU UNTUK HEADER BOX SOLID */
      .box.box-solid.box-primary > .box-header {
        color: #ffffff; background: #FF4500; background-color: #FF4500;
      }
      .box.box-solid.box-info > .box-header {
        color: #ffffff; background: #FF8C00; background-color: #FF8C00;
      }
      .box.box-solid.box-primary { border: 1px solid #FF4500; }
      .box.box-solid.box-info { border: 1px solid #FF8C00; }

      /* CSS untuk Tabel DT */
      table.dataTable thead th, table.dataTable thead td {
        background-color: #ff8c00; color: white; border-bottom: 2px solid #ff4500 !important;
      }
      .dataTables_wrapper .dataTables_filter input, 
      .dataTables_wrapper .dataTables_length select {
        border: 1px solid #ff8c00; border-radius: 4px;
      }
      .dataTables_wrapper .dataTables_paginate .paginate_button.current, 
      .dataTables_wrapper .dataTables_paginate .paginate_button.current:hover {
        background: linear-gradient(90deg, #FF8C00, #FF4500) !important;
        color: white !important; border: 1px solid #ff4500 !important;
      }
      .dataTables_wrapper .dataTables_paginate .paginate_button:hover {
        background-color: #ffc37a !important; border: 1px solid #ff8c00 !important; color: white !important;
      }
      
      /* --- CSS BARU UNTUK FILTER PETA --- */
      .map-filter .form-group { margin-bottom: 15px; }
      .map-filter label { color: #4a312f; font-weight: bold; }
      .map-filter .selectize-input { border: 1px solid #FF8C00 !important; border-radius: 4px; }
      
      /* --- CSS BARU UNTUK RANKING LIST --- */
      .list-group-item {
        border-color: #fbeed5 !important; background-color: #fffaf0 !important;
        color: #4a312f; font-weight: bold;
      }
      .list-group-item .badge {
        font-size: 14px; font-weight: bold; background-color: #FF4500 !important;
      }

      /* --- CSS BARU UNTUK INFOBOX --- */
      .info-box {
        transition: transform 0.3s ease, box-shadow 0.3s ease !important;
        border-radius: 8px !important; border: none !important; color: white !important;
      }
      .info-box:hover {
        transform: translateY(-5px) scale(1.02);
        box-shadow: 0 10px 20px rgba(0,0,0,0.2) !important;
      }
      .info-box-number {
        font-family: "Oswald", sans-serif !important; font-weight: 700 !important;
        font-size: 32px !important;
      }
      .info-box-icon { border-radius: 6px 0 0 6px; color: white !important; }
      #kejadianBox .info-box, #kejadianBox .info-box-icon { background: linear-gradient(135deg, #e74c3c, #c0392b) !important; }
      #korbanBox .info-box, #korbanBox .info-box-icon { background: linear-gradient(135deg, #34495e, #2c3e50) !important; }
      #rusakBox .info-box, #rusakBox .info-box-icon { background: linear-gradient(135deg, #f39c12, #e67e22) !important; }

      /* --- CSS BARU UNTUK SLIDER FORECASTING --- */
      .irs--shiny .irs-bar {
        border-top: 1px solid #FF4500 !important; border-bottom: 1px solid #FF4500 !important;
        background: linear-gradient(to right, #FF8C00, #FF4500) !important;
      }
      .irs--shiny .irs-line { border: 1px solid #e0d6c5 !important; }
      .irs--shiny .irs-handle { background: #FF4500 !important; border: 1px solid #c0392b !important; }
      .irs--shiny .irs-from, .irs--shiny .irs-to, .irs--shiny .irs-single {
        background-color: #4a312f !important; color: white !important;
      }
      
      /* --- CSS RESPONSIVE --- */
      @media (max-width: 768px) {
        .content-wrapper h2 { font-size: 24px; }
        .info-box-number { font-size: 26px !important; }
      }
    '))
    ),
    
    tabItems(
      # Tab 0: Landing Page
      tabItem(tabName = "landing_page",
              div(class="landing-page-content",
                  fluidRow(
                    column(width = 12, align="center",
                           h1("DASBOR ANALISIS BENCANA & IKLIM"),
                           p(class="lead", "Jelajahi Data, Pahami Risiko: Platform interaktif untuk memvisualisasikan tren, menganalisis hubungan, dan melihat peramalan kejadian bencana di Indonesia."),
                           br(),
                           tags$img(src = "logo.png", width = "20%"), 
                           br(), br(), br(),
                           actionButton("start_button", "Mulai Eksplorasi", icon = icon("arrow-right"), class = "btn-start")
                    )
                  ),
                  hr(style="margin-top: 40px; margin-bottom: 40px;"),
                  fluidRow(
                    h2("Fitur Unggulan", align="center"),
                    br(),
                    column(width = 3, class="feature-box", align="center",
                           icon("map-marked-alt", "fa-3x"),
                           h4("Peta Interaktif"),
                           p("Visualisasikan sebaran bencana per provinsi.")
                    ),
                    column(width = 3, class="feature-box", align="center",
                           icon("chart-line", "fa-3x"),
                           h4("Analisis Statistik"),
                           p("Temukan korelasi antara iklim dan dampak bencana.")
                    ),
                    column(width = 3, class="feature-box", align="center",
                           icon("clock", "fa-3x"),
                           h4("Peramalan"),
                           p("Lihat prediksi kejadian bencana di masa depan.")
                    ),
                    column(width = 3, class="feature-box", align="center",
                           icon("table", "fa-3x"),
                           h4("Jelajah Data"),
                           p("Selami data mentah dengan tabel interaktif.")
                    )
                  )
              )
      ),
      
      # Tab 1: Ringkasan
      tabItem(tabName = "ringkasan",
              h2("Ringkasan Dampak Bencana Nasional"),
              fluidRow(
                div(id = "kejadianBox", class = "col-lg-4 col-md-6 col-sm-12", infoBoxOutput("totalKejadian", width = 12)),
                div(id = "korbanBox", class = "col-lg-4 col-md-6 col-sm-12", infoBoxOutput("totalKorban", width = 12)),
                div(id = "rusakBox", class = "col-lg-4 col-md-6 col-sm-12", infoBoxOutput("totalRumahRusak", width = 12))
              ),
              fluidRow(
                box(title = "Tren Jumlah Kejadian Bencana per Tahun", width = 12, solidHeader = TRUE, status = "primary",
                    plotlyOutput("grafikKejadian") %>% withSpinner(color="#FF4500")
                )
              ),
              fluidRow(
                box(title = "Interpretasi Grafik", width = 12, solidHeader = TRUE, status = "info",
                    p("Grafik di atas menunjukkan tren jumlah kejadian bencana hidrometeorologi di Indonesia dari tahun ke tahun. Berdasarkan data yang divisualisasikan, dapat ditarik beberapa interpretasi:"),
                    tags$ul(
                      tags$li(strong("Tren Meningkat:"), "Secara umum, terlihat adanya kecenderungan peningkatan jumlah kejadian bencana dari tahun 2015 hingga mencapai puncaknya pada tahun 2021."),
                      tags$li(strong("Fluktuasi Tahunan:"), "Meskipun trennya meningkat, terdapat fluktuasi yang signifikan. Contohnya, terjadi penurunan tajam pada tahun 2022 sebelum kembali meningkat."),
                      tags$li(strong("Potensi Penyebab:"), "Peningkatan tren jangka panjang ini dapat diasosiasikan dengan dampak perubahan iklim global, degradasi lingkungan, serta peningkatan kapasitas pelaporan data.")
                    )
                )
              )
      ),
      
      # Tab 2: Peta Interaktif
      tabItem(tabName = "peta",
              h2("Peta Sebaran Kejadian Bencana"),
              fluidRow(
                column(width = 12, md = 3,
                       div(class = "map-filter",
                           selectInput("tahun", "Pilih Tahun:", choices = 2010:2023, selected = 2023)
                       )
                )
              ),
              fluidRow(
                column(width = 12, md = 8,
                       box(width = NULL, solidHeader = TRUE, status = "primary",
                           title = "Peta Choropleth Jumlah Kejadian",
                           leafletOutput("petaBencana", height = "75vh") %>% withSpinner(color="#FF4500")
                       )
                ),
                column(width = 12, md = 4,
                       box(
                         title = textOutput("ranking_title"),
                         width = NULL, solidHeader = TRUE, status = "primary",
                         uiOutput("prov_ranking_ui") %>% withSpinner(color="#FF4500")
                       )
                )
              )
      ),
      
      # Tab 3: Analisis Iklim
      tabItem(tabName = "iklim",
              h2("Analisis Hubungan Bencana dengan Iklim (Nasional)"),
              fluidRow(
                column(width = 12, md = 7,
                       box(title = "Tren Curah Hujan Tahunan", width = NULL, solidHeader = TRUE, status = "info",
                           plotlyOutput("grafikCurahHujan") %>% withSpinner(color="#FF4500"))
                ),
                column(width = 12, md = 5,
                       box(title = "Interpretasi", width = NULL, solidHeader = TRUE, status = "primary",
                           p("Grafik ini menunjukkan volatilitas curah hujan tahunan. Fluktuasi ini dapat dipengaruhi oleh fenomena iklim global seperti ENSO (El Niño/La Niña)."))
                )
              ),
              fluidRow(
                column(width = 12, md = 7,
                       box(title = "Tren Suhu Rata-rata Tahunan", width = NULL, solidHeader = TRUE, status = "info",
                           plotlyOutput("grafikTemperatur") %>% withSpinner(color="#FF4500"))
                ),
                column(width = 12, md = 5,
                       box(title = "Interpretasi", width = NULL, solidHeader = TRUE, status = "primary",
                           p("Berbeda dengan curah hujan, suhu rata-rata menunjukkan tren pemanasan jangka panjang yang lebih konsisten, sejalan dengan tren pemanasan global."))
                )
              )
      ),
      
      # Tab 4: Analisis Statistik
      tabItem(tabName = "statistik",
              h2("Analisis Korelasi & Regresi (Nasional)"),
              fluidRow(
                column(width = 12, md = 4,
                       box(title = "Pengaturan Analisis", width = NULL, status = "primary", solidHeader = TRUE,
                           selectInput("xvar", "Variabel Independen (X):", choices = c("Curah_hujan", "Temp_mean")),
                           selectInput("yvar", "Variabel Dependen (Y):", choices = c("Bencana_jumlah", "Meninggal", "Hilang", "Terendam", "Mengungsi", "Rusak Berat", "Rusak Sedang", "Rusak Ringan")),
                           checkboxInput("run_lm", "Tampilkan Garis Regresi Linier", value = TRUE),
                           checkboxInput("run_cor", "Tampilkan Hasil Uji Korelasi", value = TRUE)
                       ),
                       box(title = "Kesimpulan & Interpretasi", width = NULL, status = "primary", solidHeader = TRUE,
                           p("Bagian ini memungkinkan Anda menjelajahi hubungan statistik antara variabel iklim (X) dan dampak bencana (Y)."),
                           tags$ul(
                             tags$li(strong("Korelasi Pearson:"), "Mengukur kekuatan dan arah hubungan linear. p-value < 0.05 menunjukkan korelasi signifikan."),
                             tags$li(strong("Regresi Linier:"), "Membuat model prediksi. 'R-squared' menunjukkan persentase variasi Y yang dijelaskan oleh X.")
                           )
                       )
                ),
                column(width = 12, md = 8,
                       box(title = "Hasil Analisis", width = NULL, status = "info", solidHeader = TRUE,
                           plotOutput("stat_plot") %>% withSpinner(color="#FF4500"),
                           uiOutput("stat_output") %>% withSpinner(color="#FF4500")
                       )
                )
              )
      ),
      
      # Tab 5: Forecasting
      tabItem(tabName = "forecast",
              h2("Peramalan Jumlah Kejadian Bencana (Nasional)"),
              fluidRow(
                box(title = "Pengaturan Prediksi", width = 12, status = "info", solidHeader = TRUE,
                    sliderInput("tahun_prediksi", "Jumlah Tahun Prediksi ke Depan:", min = 1, max = 10, value = 5, width="100%")
                )
              ),
              fluidRow(
                box(title = "Grafik Prediksi (Model SARIMA)", width = 12, status = "primary", solidHeader = TRUE,
                    plotOutput("plot_forecast") %>% withSpinner(color="#FF4500")
                )
              ),
              fluidRow(
                column(width = 12, md = 7,
                       box(title = "Hasil Forecasting", width = NULL, solidHeader = TRUE, status = "primary",
                           uiOutput("forecast_details") %>% withSpinner(color="#FF4500")
                       )
                ),
                column(width = 12, md = 5,
                       box(title = "Interpretasi Model", width = NULL, solidHeader = TRUE, status = "info",
                           p(strong("Model ARIMA:"), "Model statistik untuk menganalisis dan memprediksi data deret waktu."),
                           p(strong("Metrik Akurasi:"), "Menunjukkan seberapa baik model ini cocok dengan data historis. Nilai yang lebih rendah umumnya lebih baik."),
                           p(em("Grafik di atas menampilkan prediksi (garis biru) beserta interval kepercayaan 80% dan 95% (area abu-abu)."))
                       )
                )
              )
      ),
      
      # Tab 6: Data Explorer
      tabItem(tabName = "data_explorer",
              h2("Penjelajah Data Bencana"),
              fluidRow(
                box(title = "Tabel Data", width = 12, solidHeader = TRUE, status = "primary",
                    DT::dataTableOutput("dataTable") %>% withSpinner(color="#FF4500")
                )
              )
      ),
      
      # Tab 7: Panduan Pengguna
      tabItem(tabName = "user_guide",
              h2("Panduan Pengguna Dasbor"),
              fluidRow(
                box(title = "Video Tutorial", width = 12, solidHeader = TRUE, status = "primary",
                    p("Tonton video di bawah ini untuk panduan visual singkat tentang cara menggunakan dasbor ini."),
                    HTML('<iframe width="100%" height="500" src="https://www.youtube.com/embed/cP6KQ2_-OG4" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>')
                ),
                box(title = "Panduan Tekstual", width = 12, solidHeader = TRUE, status = "info",
                    tags$ul(
                      tags$li(strong("Selamat Datang:"), "Halaman ini adalah perkenalan awal dasbor. Klik tombol 'Mulai Eksplorasi' untuk masuk ke menu utama."),
                      tags$li(strong("Ringkasan:"), "Menampilkan data agregat nasional, termasuk total kejadian, korban, dan kerusakan. Grafik di bawahnya menunjukkan tren bencana dari tahun ke tahun."),
                      tags$li(strong("Peta Interaktif:"), "Gunakan menu dropdown 'Pilih Tahun' untuk melihat data sebaran bencana pada tahun tersebut. Arahkan kursor ke sebuah provinsi untuk melihat jumlah kejadian. Peringkat provinsi dengan kejadian terbanyak ditampilkan di sisi kanan."),
                      tags$li(strong("Analisis Iklim:"), "Melihat tren data curah hujan dan suhu rata-rata nasional dari waktu ke waktu."),
                      tags$li(strong("Analisis Statistik:"), "Pilih variabel independen (X, misal: Curah_hujan) dan dependen (Y, misal: Bencana_jumlah) untuk melihat hubungan keduanya dalam scatter plot. Centang kotak untuk menampilkan garis regresi dan hasil uji statistik."),
                      tags$li(strong("Forecasting:"), "Gunakan slider untuk menentukan berapa tahun ke depan Anda ingin melihat peramalan jumlah kejadian bencana. Grafik akan menampilkan data historis dan hasil prediksi."),
                      tags$li(strong("Data Explorer:"), "Menampilkan data mentah dalam format tabel. Anda bisa mencari data spesifik menggunakan kotak pencarian di setiap kolom atau di pojok kanan atas.")
                    )
                )
              )
      ),
      
      # Tab 8: Metadata
      tabItem(tabName = "metadata",
              h2("Metadata"),
              fluidRow(
                box(title = "Informasi Data", width = 12, solidHeader = TRUE, status = "primary",
                    p("Berdasarkan Peraturan Presiden Indonesia Nomor 39 tahun 2019 tentang Satu Data Indonesia, data harus dilengkapi dengan metadata (pasal 3a) yang sesuai dengan format yang ditetapkan oleh Badan Pusat Statistik sebagai pembina data statistik (pasal 8); sebagaimana tercantum dalam Peraturan BPS No 5 tahun 2020 tentang Petunjuk Teknis Metadata Statistik, Tabel 2, page 8--12. Tabel di bawah ini berisikan metadata dari variabel dampak yang termuat dalam dataset DIBI."),
                    hr(),
                    
                    h4("Sumber Data"),
                    tags$ul(
                      tags$li("Data Jumlah Kejadian Bencana & Iklim: ", tags$a(href="https://dibi.bnpb.go.id/superset/dashboard/1/?standalone=0&expand_filters=0", target="_blank", "BNPB DIBI Dashboard")),
                      tags$li("Data Suhu Permukaan (Temperature): ", tags$a(href="https://developers.google.com/earth-engine/datasets/catalog/ECMWF_ERA5_LAND_MONTHLY_AGGR", target="_blank", "ERA5 Land Monthly - Google Earth Engine")),
                      tags$li("Data Intensitas Curah Hujan (Precipitation): ", tags$a(href="https://developers.google.com/earth-engine/datasets/catalog/UCSB-CHG_CHIRPS_DAILY", target="_blank", "CHIRPS Daily - Google Earth Engine")),
                      tags$li("Data Spasial (Peta): `indonesia-prov.geojson`")
                    ),
                    hr(),
                    
                    h4("Definisi Variabel Utama"),
                    tags$dl(
                      tags$dt("Bencana_jumlah"),
                      tags$dd("Total kejadian bencana yang tercatat dalam satu periode (bulan)."),
                      tags$dt("Meninggal / Hilang"),
                      tags$dd("Jumlah korban jiwa yang meninggal atau dinyatakan hilang akibat bencana."),
                      tags$dt("Rusak Berat / Sedang / Ringan"),
                      tags$dd("Jumlah rumah yang mengalami kerusakan sesuai kategorinya."),
                      tags$dt("Curah_hujan"),
                      tags$dd("Rata-rata curah hujan dalam satu periode (mm/hari)."),
                      tags$dt("Temp_mean"),
                      tags$dd("Rata-rata suhu udara dalam satu periode (°C).")
                    ),
                    hr(),
                    
                    h4("Cakupan Data"),
                    p("Data yang digunakan mencakup periode dari tahun 2010 hingga 2023."),
                    hr(),
                    
                    h4("Catatan"),
                    p("Jika file data asli tidak ditemukan, aplikasi akan berjalan menggunakan data dummy (simulasi) untuk keperluan demonstrasi. Oleh karena itu, interpretasi tidak boleh dianggap sebagai representasi kejadian nyata jika menggunakan data dummy.")
                )
              )
      ),
      
      # Tab 9: Tentang (KONTEN STATIS DARI MD)
      tabItem(tabName = "tentang",
              h2("Tentang Dashboard"),
              box(title = "Informasi Proyek", width = 12, solidHeader = TRUE, status = "primary",
                  p("Dashboard ini bertujuan menyediakan media analisis dan visualisasi data interaktif untuk mendukung eksplorasi dan pemahaman terhadap hubungan antara perubahan iklim dan bencana hidrometeorologi. Bencana hidrometeorologi mencakup peristiwa seperti banjir, tanah longsor, angin kencang, gelombang pasang, hingga kekeringan. Dashboard ini mengumpulkan dan mengintegrasikan data suhu permukaan dan curah hujan dari Google Earth Engine dengan data bencana hidrometeorologi dari BNPB. Dengan adanya dashboard ini diharapkan dapat bermanfaat sebagai alat bantu dalam menjawab tantangan perubahan iklim di Indonesia."),
                  hr(),
                  h4("Sumber Data"),
                  tags$ul(
                    tags$li("Badan Nasional Penanggulangan Bencana (BNPB)"),
                    tags$li("Google Earth Engine")
                  ),
                  hr(),
                  h4("Fitur Dashboard"),
                  tags$ul(
                    tags$li("Peta interaktif"),
                    tags$li("Analisis Iklim"),
                    tags$li("Forecasting"),
                    tags$li("Grafik tren"),
                    tags$li("Korelasi bencana dan iklim"),
                    tags$li("Data Explorer")
                  )
              )
      )
    )
  )
)

# --- 4. SERVER (LOGIKA APLIKASI) ---
server <- function(input, output, session) {
  
  # Logika untuk tombol di Landing Page
  observeEvent(input$start_button, {
    updateTabItems(session, "tabs", "ringkasan")
    shinyjs::removeClass(selector = "body", class = "sidebar-collapse")
  })
  
  # --- DATA REAKTIF UTAMA ---
  data_filtered <- reactive({
    full_data
  })
  
  # --- TAB 1: RINGKASAN ---
  output$totalKejadian <- renderInfoBox({
    total <- sum(data_filtered()$Bencana_jumlah, na.rm = TRUE)
    infoBox("Total Kejadian", format(total, big.mark = ","), icon = icon("exclamation-triangle"), color = "red", width = 12)
  })
  
  output$totalKorban <- renderInfoBox({
    total <- sum(data_filtered()$Meninggal, na.rm = TRUE)
    infoBox("Korban Meninggal", format(total, big.mark = ","), icon = icon("user-times"), color = "black", width = 12)
  })
  
  output$totalRumahRusak <- renderInfoBox({
    total <- sum(data_filtered()$`Rusak Berat`, na.rm = TRUE)
    infoBox("Rumah Rusak Berat", format(total, big.mark = ","), icon = icon("home"), color = "orange", width = 12)
  })
  
  output$grafikKejadian <- renderPlotly({
    plot_data <- data_filtered() %>%
      group_by(Year) %>%
      summarise(Total_Bencana = sum(Bencana_jumlah, na.rm = TRUE), .groups = 'drop')
    
    plot_ly(plot_data, x = ~Year, y = ~Total_Bencana, type = 'scatter', mode = 'lines+markers',
            line = list(color = '#D9534F', width = 3), marker = list(color = '#D9534F')) %>%
      layout(title = list(text = "Tren Nasional", y = 0.95),
             xaxis = list(title = "Tahun"),
             yaxis = list(title = "Jumlah Bencana"))
  })
  
  # --- TAB 2: PETA INTERAKTIF ---
  output$petaBencana <- renderLeaflet({
    req(input$tahun)
    dat_tahun <- data_prov %>% filter(Tahun == input$tahun)
    
    req(nrow(prov_geo) > 0)
    
    prov_join <- prov_geo %>%
      mutate(Propinsi = toupper(trimws(Propinsi))) %>%
      left_join(dat_tahun, by = c("Propinsi" = "NAME_1"))
    
    pal <- colorNumeric(palette = "YlOrRd", domain = prov_join$`Jumlah Kejadian`, na.color = "#bdc3c7")
    
    leaflet(prov_join) %>%
      addProviderTiles("CartoDB.Positron", options = providerTileOptions(minZoom = 4, maxZoom = 8)) %>%
      setView(lng = 118, lat = -2, zoom = 5) %>%
      addPolygons(
        fillColor = ~pal(`Jumlah Kejadian`),
        fillOpacity = 0.8,
        color = "white",
        weight = 1.5,
        label = ~paste0(Propinsi, ": ", format(ifelse(is.na(`Jumlah Kejadian`), 0, `Jumlah Kejadian`), big.mark = ","), " kejadian"),
        highlightOptions = highlightOptions(weight = 3, color = "#666", fillOpacity = 1, bringToFront = TRUE)
      ) %>%
      addLegend("bottomright", pal = pal, values = ~`Jumlah Kejadian`, title = "Jumlah Kejadian", opacity = 1)
  })
  
  output$ranking_title <- renderText({
    paste("Peringkat Provinsi Tahun", input$tahun)
  })
  
  output$prov_ranking_ui <- renderUI({
    req(input$tahun)
    
    ranked_data <- data_prov %>%
      filter(Tahun == input$tahun) %>%
      arrange(desc(`Jumlah Kejadian`)) %>%
      filter(!is.na(`Jumlah Kejadian`)) %>%
      mutate(Rank = row_number()) %>%
      head(10)
    
    if (nrow(ranked_data) == 0) {
      return(p("Tidak ada data untuk ditampilkan pada tahun yang dipilih."))
    }
    
    ranking_list_items <- lapply(1:nrow(ranked_data), function(i) {
      tags$li(
        class = "list-group-item",
        tags$span(class = "badge", format(ranked_data$`Jumlah Kejadian`[i], big.mark = ",")),
        paste0(ranked_data$Rank[i], ". ", ranked_data$NAME_1[i])
      )
    })
    
    tags$ul(class = "list-group", ranking_list_items)
  })
  
  # --- TAB 3: ANALISIS IKLIM ---
  output$grafikCurahHujan <- renderPlotly({
    plot_data <- data_filtered() %>%
      group_by(Year) %>%
      summarise(Hujan = mean(Curah_hujan, na.rm = TRUE))
    
    plot_ly(plot_data, x = ~Year, y = ~Hujan, type = 'scatter', mode = 'lines', line = list(color = '#f0ad4e')) %>%
      layout(title = "Curah Hujan", xaxis = list(title = "Tahun"), yaxis = list(title = "mm/hari"))
  })
  
  output$grafikTemperatur <- renderPlotly({
    plot_data <- data_filtered() %>%
      group_by(Year) %>%
      summarise(Suhu = mean(Temp_mean, na.rm = TRUE))
    
    plot_ly(plot_data, x = ~Year, y = ~Suhu, type = 'scatter', mode = 'lines', line = list(color = '#d9534f')) %>%
      layout(title = "Suhu Rata-rata", xaxis = list(title = "Tahun"), yaxis = list(title = "Suhu (°C)"))
  })
  
  # --- TAB 4: ANALISIS STATISTIK ---
  output$stat_plot <- renderPlot({
    req(input$xvar, input$yvar)
    ggplot(data_filtered(), aes_string(x = input$xvar, y = input$yvar)) +
      geom_point(alpha = 0.6, color = "#f0ad4e") +
      geom_smooth(method = if (input$run_lm) "lm" else "loess", se = FALSE, color = "#d9534f") +
      theme_minimal(base_size = 14) +
      labs(title = paste("Hubungan antara", input$xvar, "dan", input$yvar),
           subtitle = "Data Nasional")
  })
  
  output$stat_output <- renderUI({
    req(input$xvar, input$yvar)
    
    analysis_data <- data_filtered() %>%
      select(all_of(c(input$xvar, input$yvar))) %>%
      na.omit()
    
    req(nrow(analysis_data) > 2)
    
    tags_list <- list()
    
    if (input$run_cor) {
      cor_ui <- tryCatch({
        cor_test <- cor.test(analysis_data[[input$xvar]], analysis_data[[input$yvar]], method = "pearson")
        r_val <- cor_test$estimate
        p_val <- cor_test$p.value
        
        direction <- if (r_val > 0) "positif" else "negatif"
        strength <- case_when(
          abs(r_val) < 0.2 ~ "sangat lemah",
          abs(r_val) < 0.4 ~ "lemah",
          abs(r_val) < 0.6 ~ "sedang",
          abs(r_val) < 0.8 ~ "kuat",
          TRUE ~ "sangat kuat"
        )
        significance <- if (p_val < 0.05) "signifikan secara statistik" else "tidak signifikan secara statistik"
        meaning <- if (direction == "positif") {
          paste("Artinya, ada kecenderungan bahwa ketika nilai", strong(input$xvar), "meningkat, nilai", strong(input$yvar), "juga ikut meningkat.")
        } else {
          paste("Artinya, ada kecenderungan bahwa ketika nilai", strong(input$xvar), "meningkat, nilai", strong(input$yvar), "cenderung menurun.")
        }
        
        interpretation_text_cor <- tags$p(tags$em(
          HTML(paste0("Interpretasi: Ditemukan ", strong(paste("korelasi", direction, "yang", strength)), " (r = ", round(r_val, 3), ") antara ", strong(input$xvar), " dan ", strong(input$yvar), ". Hubungan ini ", strong(significance), " (p-value = ", format.pval(p_val, digits = 3, eps = 0.001), "). ", meaning))
        ))
        
        tagList(
          h4("Hasil Korelasi Pearson"),
          p(strong("Koefisien Korelasi (r): "), round(r_val, 3)),
          interpretation_text_cor,
          hr()
        )
        
      }, error = function(e) {
        tagList(h4("Hasil Korelasi Pearson"), p("Analisis korelasi gagal: ", e$message))
      })
      
      tags_list <- append(tags_list, list(cor_ui))
    }
    
    if (input$run_lm) {
      lm_ui <- tryCatch({
        lm_model <- lm(as.formula(paste(input$yvar, "~", input$xvar)), data = analysis_data)
        summary_lm <- summary(lm_model)
        r_squared_val <- summary_lm$r.squared
        r_squared_percent <- round(r_squared_val * 100, 1)
        
        interpretation_text_lm <- tags$p(tags$em(
          HTML(paste0("Interpretasi: Nilai R-squared menunjukkan bahwa sekitar ", strong(paste0(r_squared_percent, "%")), " variabilitas pada variabel ", strong(input$yvar), " dapat dijelaskan oleh perubahan pada variabel ", strong(input$xvar), " dalam model ini. Sisanya (", 100 - r_squared_percent, "%) dipengaruhi oleh faktor-faktor lain."))
        ))
        
        tagList(
          h4("Hasil Regresi Linier"),
          p(strong("R-squared: "), round(r_squared_val, 3)),
          interpretation_text_lm,
          tags$h5("Detail Model:"),
          tags$pre(paste(capture.output(summary_lm), collapse = "\n"))
        )
        
      }, error = function(e) {
        tagList(h4("Hasil Regresi Linier"), p("Analisis regresi gagal: ", e$message))
      })
      
      tags_list <- append(tags_list, list(lm_ui))
    }
    
    tagList(tags_list)
  })
  
  # --- TAB 5: FORECASTING ---
  forecast_model <- reactive({
    req(data_filtered())
    data_ts <- data_filtered() %>%
      arrange(Year, Month) %>%
      mutate(tanggal = as.Date(paste(Year, Month, 1, sep = "-"))) %>%
      group_by(tanggal) %>%
      summarise(total = sum(Bencana_jumlah, na.rm = TRUE))
    
    req(nrow(data_ts) >= 24)
    ts_data <- ts(data_ts$total, start = c(year(min(data_ts$tanggal)), month(min(data_ts$tanggal))), frequency = 12)
    
    tryCatch({ auto.arima(ts_data, seasonal = TRUE) }, error = function(e) { NULL })
  })
  
  output$plot_forecast <- renderPlot({
    model <- forecast_model()
    req(model)
    prediksi <- forecast(model, h = input$tahun_prediksi * 12)
    autoplot(prediksi) + 
      labs(title = "Prediksi Jumlah Kejadian Bencana Nasional", x = "Waktu", y = "Jumlah Bencana") +
      theme_minimal(base_size = 14)
  })
  
  output$forecast_details <- renderUI({
    model <- forecast_model()
    req(model)
    accuracy_metrics <- accuracy(model)
    tagList(
      h4("Ringkasan Model"),
      p(strong("Model Terbaik: "), model$method),
      h4("Metrik Akurasi Model"),
      tags$table(class="table table-striped table-hover",
                 tags$thead(tags$tr(lapply(colnames(accuracy_metrics), tags$th))),
                 tags$tbody(tags$tr(lapply(round(accuracy_metrics, 3), tags$td)))
      )
    )
  })
  
  # --- TAB 6: DATA EXPLORER ---
  output$dataTable <- DT::renderDataTable({
    DT::datatable(data_filtered(),
                  options = list(pageLength = 10, scrollX = TRUE),
                  rownames = FALSE, filter = 'top', class = 'cell-border stripe')
  })
  
  
  
}

# --- 5. MENJALANKAN APLIKASI ---
shinyApp(ui, server)
