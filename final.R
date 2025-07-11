# --- 1. MEMUAT PUSTAKA YANG DIPERLUKAN ---
# Pastikan semua pustaka ini sudah terinstal: install.packages(c("shiny", "shinydashboard", ...))
library(shiny)
library(shinydashboard)
library(leaflet)
library(tidyverse)
library(plotly)
library(readxl)
library(forecast)
library(ggfortify)
library(sf)
library(shinycssloaders) # Untuk indikator loading
library(DT)             # Untuk tabel interaktif

# --- 2. MEMUAT DAN MEMPERSIAPKAN DATA ---
# Catatan: Pastikan file data berada di direktori yang benar
# Membaca data dari file CSV yang diunggah.
tryCatch({
  full_data <- read_csv("DataKomstat_Gabung.xlsx - komstat.csv")
  data_prov <- read_csv("DataKomstat_Provinsi.xlsx - Sheet1.csv")
  message("Berhasil memuat file data CSV.")
}, error = function(e) {
  # Membuat data dummy jika file tidak ada untuk memastikan aplikasi tetap berjalan
  message("File data CSV tidak ditemukan. Menggunakan data dummy sebagai gantinya.")
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
# Ganti 'Wilayah' dengan nama kolom provinsi yang benar di data_prov jika berbeda
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
  dashboardHeader(title = span("Dashboard Bencana & Iklim", style = "font-weight: bold; font-size: 20px;")),
  
  # Sidebar
  dashboardSidebar(
    sidebarMenu(id = "tabs",
                # Filter provinsi dan analisis jenis bencana dihapus
                menuItem("Ringkasan", tabName = "ringkasan", icon = icon("tachometer-alt")),
                menuItem("Peta Interaktif", tabName = "peta", icon = icon("map-marked-alt")),
                menuItem("Analisis Iklim", tabName = "iklim", icon = icon("cloud-sun-rain")),
                menuItem("Analisis Statistik", tabName = "statistik", icon = icon("chart-line")),
                menuItem("Forecasting", tabName = "forecast", icon = icon("clock")),
                menuItem("Data Explorer", tabName = "data_explorer", icon = icon("table")),
                menuItem("Tentang", tabName = "tentang", icon = icon("info-circle"))
    )
  ),
  
  # Body
  dashboardBody(
    # --- CSS Kustom untuk Tampilan Gradasi Oranye-Merah ---
    tags$head(
      # --- PENAMBAHAN META TAG VIEWPORT UNTUK RESPONSIVITAS ---
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1.0"),
      tags$style(HTML('
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
      .content-wrapper { 
        background-color: rgb(255, 248, 235) !important; /* Warna Krem Baru */
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
      /* --- AKHIR ANIMASI SIDEBAR --- */

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
        color: #ffffff;
        background: #FF4500; /* OrangeRed */
        background-color: #FF4500; /* OrangeRed */
      }
      .box.box-solid.box-info > .box-header {
        color: #ffffff;
        background: #FF8C00; /* DarkOrange */
        background-color: #FF8C00; /* DarkOrange */
      }
      .box.box-solid.box-primary {
        border: 1px solid #FF4500;
      }
      .box.box-solid.box-info {
        border: 1px solid #FF8C00;
      }
      /* AKHIR CSS HEADER BOX */

      /* CSS untuk Tabel DT */
      table.dataTable thead th, table.dataTable thead td {
        background-color: #ff8c00; /* Dark Orange */
        color: white;
        border-bottom: 2px solid #ff4500 !important; /* OrangeRed */
      }

      .dataTables_wrapper .dataTables_filter input, 
      .dataTables_wrapper .dataTables_length select {
        border: 1px solid #ff8c00;
        border-radius: 4px;
      }

      .dataTables_wrapper .dataTables_paginate .paginate_button.current, 
      .dataTables_wrapper .dataTables_paginate .paginate_button.current:hover {
        background: linear-gradient(90deg, #FF8C00, #FF4500) !important;
        color: white !important;
        border: 1px solid #ff4500 !important;
      }

      .dataTables_wrapper .dataTables_paginate .paginate_button:hover {
        background-color: #ffc37a !important;
        border: 1px solid #ff8c00 !important;
        color: white !important;
      }
      /* AKHIR CSS TABEL */
      
      /* --- CSS BARU UNTUK FILTER PETA --- */
      .map-filter .form-group {
        margin-bottom: 15px;
      }
      .map-filter label {
        color: #4a312f; /* Dark brown color */
        font-weight: bold;
      }
      .map-filter .selectize-input {
        border: 1px solid #FF8C00 !important; /* Orange border */
        border-radius: 4px;
      }
      /* --- AKHIR CSS FILTER PETA --- */
      
      /* --- CSS BARU UNTUK RANKING LIST --- */
      .list-group-item {
        border-color: #fbeed5 !important;
        background-color: #fffaf0 !important;
        color: #4a312f;
        font-weight: bold;
      }
      .list-group-item .badge {
        font-size: 14px;
        font-weight: bold;
        background-color: #FF4500 !important;
      }
      /* --- AKHIR CSS RANKING LIST --- */

      /* --- CSS BARU UNTUK INFOBOX --- */
      .info-box {
        transition: transform 0.3s ease, box-shadow 0.3s ease !important;
        border-radius: 8px !important;
        border: none !important;
        color: white !important;
      }
      .info-box:hover {
        transform: translateY(-5px) scale(1.02);
        box-shadow: 0 10px 20px rgba(0,0,0,0.2) !important;
      }
      .info-box-number {
        font-family: "Oswald", sans-serif !important;
        font-weight: 700 !important;
        font-size: 32px !important;
      }
      .info-box-icon {
        border-radius: 6px 0 0 6px;
        color: white !important;
      }
      /* Menerapkan gradasi pada infoBox standar */
      #kejadianBox .info-box, #kejadianBox .info-box-icon { background: linear-gradient(135deg, #e74c3c, #c0392b) !important; }
      #korbanBox .info-box, #korbanBox .info-box-icon { background: linear-gradient(135deg, #34495e, #2c3e50) !important; }
      #rusakBox .info-box, #rusakBox .info-box-icon { background: linear-gradient(135deg, #f39c12, #e67e22) !important; }
      /* --- AKHIR CSS INFOBOX --- */

      /* --- CSS BARU UNTUK SLIDER FORECASTING --- */
      .irs--shiny .irs-bar {
        border-top: 1px solid #FF4500 !important;
        border-bottom: 1px solid #FF4500 !important;
        background: linear-gradient(to right, #FF8C00, #FF4500) !important;
      }
      .irs--shiny .irs-line {
        border: 1px solid #e0d6c5 !important;
      }
      .irs--shiny .irs-handle {
        background: #FF4500 !important;
        border: 1px solid #c0392b !important;
        box-shadow: 0 1px 3px rgba(0,0,0,.3) !important;
      }
      .irs--shiny .irs-handle:hover {
        background: #c0392b !important;
      }
      .irs--shiny .irs-from, .irs--shiny .irs-to, .irs--shiny .irs-single {
        background-color: #4a312f !important;
        color: white !important;
      }
      .irs--shiny .irs-from:after, .irs--shiny .irs-to:after, .irs--shiny .irs-single:after {
        border-top-color: #4a312f !important;
      }
      /* --- AKHIR CSS SLIDER --- */
      
      /* --- CSS RESPONSIVE --- */
      @media (max-width: 768px) {
        .content-wrapper h2 {
          font-size: 24px;
        }
        .info-box-number {
          font-size: 26px !important;
        }
        .info-box-text {
          font-size: 14px;
        }
      }
      /* --- AKHIR CSS RESPONSIVE --- */

    '))),
    
    tabItems(
      # Tab 1: Ringkasan
      tabItem(tabName = "ringkasan",
              h2("Ringkasan Dampak Bencana Nasional"),
              fluidRow(
                # Menggunakan div wrapper untuk menargetkan infoBox dengan CSS
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
                      tags$li(strong("Tren Meningkat:"), "Secara umum, terlihat adanya kecenderungan peningkatan jumlah kejadian bencana dari tahun 2015 hingga mencapai puncaknya pada tahun 2021. Hal ini mengindikasikan bahwa frekuensi bencana hidrometeorologi semakin tinggi dalam kurun waktu tersebut."),
                      tags$li(strong("Fluktuasi Tahunan:"), "Meskipun trennya meningkat, terdapat fluktuasi yang signifikan. Contohnya, terjadi penurunan tajam pada tahun 2022 sebelum kembali meningkat. Fluktuasi ini bisa dipengaruhi oleh berbagai faktor, termasuk anomali iklim seperti La Niña atau El Niño yang terjadi pada tahun-tahun tertentu."),
                      tags$li(strong("Potensi Penyebab:"), "Peningkatan tren jangka panjang ini dapat diasosiasikan dengan dampak perubahan iklim global, degradasi lingkungan, perubahan tata guna lahan, serta peningkatan kapasitas pelaporan dan pencatatan data bencana di tingkat nasional.")
                    )
                )
              )
      ),
      
      # Tab Analisis Jenis Bencana dihapus
      
      # Tab 3: Peta Interaktif
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
                         width = NULL, 
                         solidHeader = TRUE, 
                         status = "primary",
                         uiOutput("prov_ranking_ui") %>% withSpinner(color="#FF4500")
                       )
                )
              )
      ),
      
      # Tab 4: Analisis Iklim
      tabItem(tabName = "iklim",
              h2("Analisis Hubungan Bencana dengan Iklim (Nasional)"),
              fluidRow(
                column(width = 12, md = 7,
                       box(title = "Tren Curah Hujan Tahunan", width = NULL, solidHeader = TRUE, status = "info",
                           plotlyOutput("grafikCurahHujan") %>% withSpinner(color="#FF4500"))
                ),
                column(width = 12, md = 5,
                       box(title = "Interpretasi", width = NULL, solidHeader = TRUE, status = "primary",
                           p("Grafik ini menunjukkan volatilitas curah hujan tahunan. Fluktuasi ini dapat dipengaruhi oleh fenomena iklim global seperti ENSO (El Niño/La Niña), yang menyebabkan tahun-tahun tertentu menjadi lebih kering atau lebih basah dari biasanya."))
                )
              ),
              fluidRow(
                column(width = 12, md = 7,
                       box(title = "Tren Suhu Rata-rata Tahunan", width = NULL, solidHeader = TRUE, status = "info",
                           plotlyOutput("grafikTemperatur") %>% withSpinner(color="#FF4500"))
                ),
                column(width = 12, md = 5,
                       box(title = "Interpretasi", width = NULL, solidHeader = TRUE, status = "primary",
                           p("Berbeda dengan curah hujan, suhu rata-rata menunjukkan tren pemanasan jangka panjang yang lebih konsisten. Kenaikan suhu ini sejalan dengan tren pemanasan global yang sedang terjadi."))
                )
              )
      ),
      
      # Tab 5: Analisis Statistik
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
                           p("Bagian ini memungkinkan Anda untuk menjelajahi hubungan statistik antara variabel iklim (sebagai variabel independen X) dan dampak bencana (sebagai variabel dependen Y)."),
                           tags$ul(
                             tags$li(strong("Korelasi Pearson:"), "Mengukur kekuatan dan arah hubungan linear antara dua variabel. Nilai 'p-value' yang rendah (biasanya < 0.05) menunjukkan bahwa korelasi yang teramati signifikan secara statistik."),
                             tags$li(strong("Regresi Linier:"), "Membuat model matematis untuk memprediksi variabel Y berdasarkan variabel X. 'R-squared' menunjukkan persentase variasi pada Y yang dapat dijelaskan oleh X. 'Estimate' untuk variabel X menunjukkan seberapa besar perubahan Y untuk setiap satu unit perubahan pada X.")
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
      
      # Tab 6: Forecasting
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
                           p(strong("Model ARIMA:"), "Model ARIMA (Autoregressive Integrated Moving Average) adalah model statistik yang digunakan untuk menganalisis dan memprediksi data deret waktu. Model ini secara otomatis dipilih berdasarkan struktur data historis untuk menemukan pola terbaik."),
                           p(strong("Metrik Akurasi:"), "Tabel di sebelah kiri menunjukkan beberapa metrik untuk mengevaluasi seberapa baik model ini cocok dengan data historis. Nilai yang lebih rendah pada metrik seperti RMSE (Root Mean Squared Error) dan MAE (Mean Absolute Error) umumnya menunjukkan model yang lebih akurat."),
                           p(em("Grafik di atas menampilkan prediksi untuk periode mendatang (garis biru) beserta interval kepercayaan 80% (area abu-abu muda) dan 95% (area abu-abu tua)."))
                       )
                )
              )
      ),
      
      # Tab 7: Data Explorer
      tabItem(tabName = "data_explorer",
              h2("Penjelajah Data Bencana"),
              fluidRow(
                box(title = "Tabel Data", width = 12, solidHeader = TRUE, status = "primary",
                    DT::dataTableOutput("dataTable") %>% withSpinner(color="#FF4500")
                )
              )
      ),
      
      # Tab 8: Tentang
      tabItem(tabName = "tentang",
              box(title = "Tentang Dasbor Ini", width = 12, solidHeader = TRUE, status = "primary",
                  uiOutput("about_content")
              )
      )
    )
  )
)

# --- 4. SERVER (LOGIKA APLIKASI) ---
server <- function(input, output, session) {
  
  # --- DATA REAKTIF UTAMA ---
  # Karena filter provinsi dihapus, data ini sekarang selalu data lengkap (nasional)
  data_filtered <- reactive({
    full_data
  })
  
  # Observe untuk update provinsi dihapus
  
  # --- TAB 1: RINGKASAN ---
  # --- KEMBALI MENGGUNAKAN renderInfoBox ---
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
  
  # --- Plot Jenis Bencana Dihapus ---
  
  # --- TAB 3: PETA INTERAKTIF ---
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
  
  # --- OUTPUT BARU UNTUK PERINGKAT PROVINSI ---
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
  
  # --- TAB 4: ANALISIS IKLIM ---
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
  
  # --- TAB 5: ANALISIS STATISTIK ---
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
    req(nrow(data_filtered()) > 2)
    
    tags_list <- list()
    
    # Analisis Korelasi
    if (input$run_cor) {
      if(var(data_filtered()[[input$xvar]], na.rm=TRUE) > 0 && var(data_filtered()[[input$yvar]], na.rm=TRUE) > 0) {
        cor_test <- cor.test(data_filtered()[[input$xvar]], data_filtered()[[input$yvar]], method = "pearson")
        
        r_value <- round(cor_test$estimate, 3)
        p_value <- format.pval(cor_test$p.value, digits = 3, eps = 0.001)
        conf_int <- paste0("[", round(cor_test$conf.int[1], 3), ", ", round(cor_test$conf.int[2], 3), "]")
        
        significance_text <- if(cor_test$p.value < 0.05) {
          "Hubungan ini signifikan secara statistik (p < 0.05)."
        } else {
          "Hubungan ini tidak signifikan secara statistik (p >= 0.05)."
        }
        
        tags_list <- append(tags_list, list(
          h4("Hasil Korelasi Pearson"),
          p(strong("Koefisien Korelasi (r): "), r_value),
          p(strong("P-value: "), p_value),
          p(strong("95% Confidence Interval: "), conf_int),
          p(em(significance_text)),
          hr()
        ))
      } else {
        tags_list <- append(tags_list, list(
          h4("Hasil Korelasi Pearson"),
          p("Tidak dapat menghitung korelasi: salah satu variabel memiliki varians nol.")
        ))
      }
    }
    
    # Analisis Regresi
    if (input$run_lm) {
      lm_model <- lm(as.formula(paste(input$yvar, "~", input$xvar)), data = data_filtered())
      summary_lm <- summary(lm_model)
      
      r_squared <- round(summary_lm$r.squared, 3)
      adj_r_squared <- round(summary_lm$adj.r.squared, 3)
      f_statistic <- summary_lm$fstatistic
      f_value <- round(f_statistic[1], 2)
      f_p_value <- format.pval(pf(f_statistic[1], f_statistic[2], f_statistic[3], lower.tail = FALSE), digits=3, eps=0.001)
      
      tags_list <- append(tags_list, list(
        h4("Hasil Regresi Linier"),
        p(strong("Model: "), paste0(input$yvar, " ~ ", input$xvar)),
        p(strong("R-squared: "), r_squared),
        p(strong("Adjusted R-squared: "), adj_r_squared),
        p(em(paste0("Sekitar ", r_squared*100, "% variasi pada '", input$yvar, "' dapat dijelaskan oleh '", input$xvar, "'."))),
        p(strong("F-statistic: "), paste(f_value, "dengan p-value:", f_p_value)),
        br(),
        h5("Koefisien Model:"),
        tags$table(class="table table-striped table-hover",
                   tags$thead(
                     tags$tr(
                       tags$th("Term"),
                       tags$th("Estimate"),
                       tags$th("Std. Error"),
                       tags$th("t value"),
                       tags$th("Pr(>|t|)")
                     )
                   ),
                   tags$tbody(
                     tags$tr(
                       tags$td("(Intercept)"),
                       tags$td(round(coef(summary_lm)[1,1], 3)),
                       tags$td(round(coef(summary_lm)[1,2], 3)),
                       tags$td(round(coef(summary_lm)[1,3], 3)),
                       tags$td(format.pval(coef(summary_lm)[1,4], digits=3, eps=0.001))
                     ),
                     tags$tr(
                       tags$td(input$xvar),
                       tags$td(round(coef(summary_lm)[2,1], 3)),
                       tags$td(round(coef(summary_lm)[2,2], 3)),
                       tags$td(round(coef(summary_lm)[2,3], 3)),
                       tags$td(format.pval(coef(summary_lm)[2,4], digits=3, eps=0.001))
                     )
                   )
        ),
        hr()
      ))
    }
    
    tagList(tags_list)
  })
  
  # --- TAB 6: FORECASTING ---
  forecast_model <- reactive({
    req(data_filtered())
    data_ts <- data_filtered() %>%
      arrange(Year, Month) %>%
      mutate(tanggal = as.Date(paste(Year, Month, 1, sep = "-"))) %>%
      group_by(tanggal) %>%
      summarise(total = sum(Bencana_jumlah, na.rm = TRUE))
    
    req(nrow(data_ts) >= 24)
    
    ts_data <- ts(data_ts$total, start = c(year(min(data_ts$tanggal)), month(min(data_ts$tanggal))), frequency = 12)
    
    tryCatch({
      auto.arima(ts_data, seasonal = TRUE)
    }, error = function(e) {
      NULL
    })
  })
  
  output$plot_forecast <- renderPlot({
    model <- forecast_model()
    req(model)
    
    prediksi <- forecast(model, h = input$tahun_prediksi * 12)
    
    autoplot(prediksi) + 
      labs(title = "Prediksi Jumlah Kejadian Bencana Nasional",
           subtitle = "Menggunakan model SARIMA Otomatis",
           x = "Waktu", y = "Jumlah Bencana") +
      theme_minimal(base_size = 14)
  })
  
  # --- PERUBAHAN PADA FORECASTING OUTPUT ---
  output$forecast_details <- renderUI({
    model <- forecast_model()
    req(model)
    
    accuracy_metrics <- accuracy(model)
    
    tagList(
      h4("Ringkasan Model"),
      p(strong("Model Terbaik: "), model$method),
      hr(),
      h4("Metrik Akurasi Model (pada data training)"),
      tags$table(class="table table-striped table-hover",
                 tags$thead(
                   tags$tr(
                     lapply(colnames(accuracy_metrics), tags$th)
                   )
                 ),
                 tags$tbody(
                   tags$tr(
                     lapply(round(accuracy_metrics, 3), tags$td)
                   )
                 )
      )
    )
  })
  
  # --- TAB 7: DATA EXPLORER ---
  output$dataTable <- DT::renderDataTable({
    DT::datatable(data_filtered(),
                  options = list(pageLength = 10, scrollX = TRUE),
                  rownames = FALSE,
                  filter = 'top',
                  class = 'cell-border stripe')
  })
  
  # --- TAB 8: TENTANG ---
  output$about_content <- renderUI({
    if (file.exists("about.md")) {
      includeMarkdown("about.md")
    } else {
      div(
        h4("Tentang Dasbor"),
        p("Dasbor ini dibuat untuk memvisualisasikan dan menganalisis data kebencanaan dan iklim di seluruh Indonesia."),
        p("Gunakan menu di sebelah kiri untuk menavigasi berbagai fitur analisis, termasuk ringkasan nasional, peta interaktif, analisis iklim, dan peramalan."),
        hr(),
        p("Sumber Data: Data Komstat (dummy/provided)."),
        p("Dibuat dengan R dan Shiny.")
      )
    }
  })
}

# --- 5. MENJALANKAN APLIKASI ---
shinyApp(ui, server)
