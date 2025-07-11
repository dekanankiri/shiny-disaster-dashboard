# --- 1. MEMUAT PUSTAKA INTI (SANGAT RINGAN) ---
# Hanya pustaka yang mutlak diperlukan saat startup.
library(shiny)
library(shinydashboard)
library(dplyr)
library(shinycssloaders)

# --- 2. MEMUAT DATA YANG SUDAH DIPROSES DENGAN CEPAT ---
# Metode ini sudah benar dan sangat efisien.
load("data/disaster_data_clean.RData")


# --- 3. UI (ANTARMUKA PENGGUNA) ---
# Bagian UI tidak perlu diubah, karena sudah efisien.
ui <- dashboardPage(
  # Header
  dashboardHeader(title = span("Dashboard Bencana & Iklim", style = "font-weight: bold; font-size: 20px;")),
  
  # Sidebar
  dashboardSidebar(
    sidebarMenu(id = "tabs",
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
    # --- CSS Kustom ---
    tags$head(
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
          min-height: 100vh;
        }

        /* --- ANIMASI SIDEBAR MENU --- */
        .skin-blue .sidebar-menu > li > a {
          transition: background-color 0.3s ease, padding-left 0.3s ease;
        }
        .skin-blue .sidebar-menu > li.active > a, 
        .skin-blue .sidebar-menu > li:hover > a {
          background-color: #614a48 !important;
          border-left-color: #ff6347 !important; /* Tomato Red */
          padding-left: 20px !important;
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
        
        .box.box-primary { border-top-color: #FF4500 !important; }
        .box.box-info { border-top-color: #FF8C00 !important; }

        /* CSS untuk Tabel DT */
        table.dataTable thead th, table.dataTable thead td {
          background-color: #ff8c00; /* Dark Orange */
          color: white;
          border-bottom: 2px solid #ff4500 !important; /* OrangeRed */
        }
      '))
    ),
    
    tabItems(
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
              )
      ),
      
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
                         width = NULL, solidHeader = TRUE, status = "primary",
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
                           p("Grafik ini menunjukkan volatilitas curah hujan tahunan."))
                )
              ),
              fluidRow(
                column(width = 12, md = 7,
                       box(title = "Tren Suhu Rata-rata Tahunan", width = NULL, solidHeader = TRUE, status = "info",
                           plotlyOutput("grafikTemperatur") %>% withSpinner(color="#FF4500"))
                ),
                column(width = 12, md = 5,
                       box(title = "Interpretasi", width = NULL, solidHeader = TRUE, status = "primary",
                           p("Suhu rata-rata menunjukkan tren pemanasan jangka panjang yang konsisten."))
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

# --- 4. SERVER (LOGIKA APLIKASI DENGAN LAZY LOADING) ---
server <- function(input, output, session) {
  
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
    # Pustaka dimuat hanya saat tab ini aktif
    library(plotly)
    
    plot_data <- data_filtered() %>%
      group_by(Year) %>%
      summarise(Total_Bencana = sum(Bencana_jumlah, na.rm = TRUE), .groups = 'drop')
    
    plot_ly(plot_data, x = ~Year, y = ~Total_Bencana, type = 'scatter', mode = 'lines+markers',
            line = list(color = '#D9534F', width = 3), marker = list(color = '#D9534F')) %>%
      layout(title = list(text = "Tren Nasional", y = 0.95),
             xaxis = list(title = "Tahun"),
             yaxis = list(title = "Jumlah Bencana"))
  })
  
  # --- TAB 3: PETA INTERAKTIF ---
  output$petaBencana <- renderLeaflet({
    # Pustaka berat untuk peta dimuat hanya saat tab ini aktif
    library(leaflet)
    library(sf)
    
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
  
  # --- TAB 4: ANALISIS IKLIM ---
  output$grafikCurahHujan <- renderPlotly({
    library(plotly)
    plot_data <- data_filtered() %>%
      group_by(Year) %>%
      summarise(Hujan = mean(Curah_hujan, na.rm = TRUE))
    
    plot_ly(plot_data, x = ~Year, y = ~Hujan, type = 'scatter', mode = 'lines', line = list(color = '#f0ad4e')) %>%
      layout(title = "Curah Hujan", xaxis = list(title = "Tahun"), yaxis = list(title = "mm/hari"))
  })
  
  output$grafikTemperatur <- renderPlotly({
    library(plotly)
    plot_data <- data_filtered() %>%
      group_by(Year) %>%
      summarise(Suhu = mean(Temp_mean, na.rm = TRUE))
    
    plot_ly(plot_data, x = ~Year, y = ~Suhu, type = 'scatter', mode = 'lines', line = list(color = '#d9534f')) %>%
      layout(title = "Suhu Rata-rata", xaxis = list(title = "Tahun"), yaxis = list(title = "Suhu (°C)"))
  })
  
  # --- TAB 5: ANALISIS STATISTIK ---
  output$stat_plot <- renderPlot({
    library(ggplot2)
    
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
    
    # ... (logika untuk output ini tidak memerlukan pustaka berat, jadi tidak ada perubahan)
    # ... (kode Anda sebelumnya sudah efisien)
    tags_list <- list()
    if (input$run_cor) {
      if(var(data_filtered()[[input$xvar]], na.rm=TRUE) > 0 && var(data_filtered()[[input$yvar]], na.rm=TRUE) > 0) {
        cor_test <- cor.test(data_filtered()[[input$xvar]], data_filtered()[[input$yvar]], method = "pearson")
        tags_list <- append(tags_list, list(h4("Hasil Korelasi Pearson"), p(strong("Koefisien (r): "), round(cor_test$estimate, 3))))
      }
    }
    if (input$run_lm) {
      lm_model <- lm(as.formula(paste(input$yvar, "~", input$xvar)), data = data_filtered())
      summary_lm <- summary(lm_model)
      tags_list <- append(tags_list, list(hr(), h4("Hasil Regresi Linier"), p(strong("R-squared: "), round(summary_lm$r.squared, 3))))
    }
    tagList(tags_list)
  })
  
  # --- TAB 6: FORECASTING ---
  forecast_model <- reactive({
    # Pustaka berat untuk peramalan dimuat hanya saat tab ini aktif
    library(forecast)
    library(lubridate)
    
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
    library(ggfortify)
    
    model <- forecast_model()
    req(model)
    
    prediksi <- forecast::forecast(model, h = input$tahun_prediksi * 12)
    
    autoplot(prediksi) + 
      labs(title = "Prediksi Jumlah Kejadian Bencana Nasional",
           subtitle = "Menggunakan model SARIMA Otomatis",
           x = "Waktu", y = "Jumlah Bencana") +
      theme_minimal(base_size = 14)
  })
  
  output$forecast_details <- renderUI({
    model <- forecast_model()
    req(model)
    
    accuracy_metrics <- forecast::accuracy(model)
    
    tagList(
      h4("Ringkasan Model"),
      p(strong("Model Terbaik: "), model$method),
      hr(),
      h4("Metrik Akurasi Model"),
      tags$table(class="table table-striped table-hover",
                 tags$thead(tags$tr(lapply(colnames(accuracy_metrics), tags$th))),
                 tags$tbody(tags$tr(lapply(round(accuracy_metrics, 3), tags$td)))
      )
    )
  })
  
  # --- TAB 7: DATA EXPLORER ---
  output$dataTable <- DT::renderDataTable({
    # Pustaka DT dimuat hanya saat tab ini aktif
    library(DT)
    DT::datatable(data_filtered(),
                  options = list(pageLength = 10, scrollX = TRUE),
                  rownames = FALSE,
                  filter = 'top',
                  class = 'cell-border stripe')
  })
  
  # --- TAB 8: TENTANG ---
  output$about_content <- renderUI({
    # Tidak perlu pustaka berat
    if (file.exists("about.md")) {
      includeMarkdown("about.md")
    } else {
      p("File about.md tidak ditemukan.")
    }
  })
}

# --- 5. MENJALANKAN APLIKASI ---
shinyApp(ui, server)
