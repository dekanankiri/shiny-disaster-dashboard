library(shiny)
library(shinydashboard)
library(leaflet)
library(tidyverse)
library(plotly)
library(readxl)
library(forecast)
library(ggfortify)
library(sf)
#ngetes push pull github
# Load data
full_data <- read_excel("data/DataKomstat_Gabung.xlsx", sheet = "komstat")
data_prov <- read_excel("data/DataKomstat_Provinsi.xlsx")

# Pastikan kolom numerik valid
full_data[c("Bencana_jumlah", "Meninggal", "Hilang", "Terendam", "Mengungsi", "Rusak Berat", "Rusak Sedang", "Rusak Ringan", "Curah_hujan", "Temp_mean")] <-
  lapply(full_data[c("Bencana_jumlah", "Meninggal", "Hilang", "Terendam", "Mengungsi", "Rusak Berat", "Rusak Sedang", "Rusak Ringan", "Curah_hujan", "Temp_mean")], 
         function(x) as.numeric(as.character(x)))

# GeoJSON untuk provinsi Indonesia
prov_geo <- st_read("www/indonesia-prov.geojson", quiet = TRUE)

# Siapkan data provinsi dan samakan nama
data_prov$NAME_1 <- toupper(trimws(data_prov$Wilayah))
data_prov$`Jumlah Kejadian` <- as.numeric(gsub(",", "", data_prov$`Jumlah Kejadian`))

# Standarisasi nama kolom GeoJSON
prov_geo$Propinsi <- toupper(trimws(prov_geo$Propinsi))

# Tambahkan kolom koordinat dummy (jika belum tersedia dalam dataset)
set.seed(123)
full_data$latitude <- runif(nrow(full_data), -10, 5)
full_data$longitude <- runif(nrow(full_data), 95, 141)

ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = span("Dashboard Bencana & Iklim Indonesia", style = "font-weight: bold; font-size: 20px; color: white")),
  dashboardSidebar(
    tags$head(tags$style(HTML('body, label, input, button, select { font-family: "Segoe UI", sans-serif; }'))),
    selectInput("provinsi", "Pilih Provinsi:", choices = NULL)
  ),
  dashboardBody(
    tags$head(tags$style(HTML('
      .content-wrapper, .right-side {
        background-color: #f8f9fa;
      }
      .box {
        border-radius: 10px;
        box-shadow: 2px 2px 10px rgba(0,0,0,0.05);
      }
      .box-header {
        font-weight: bold;
        font-size: 16px;
      }
    '))),
    tabsetPanel(
      tabPanel(title = tagList(icon("chart-pie"), "Ringkasan Nasional"), 
               fluidRow(
                 valueBoxOutput("totalKejadian"),
                 valueBoxOutput("totalKorban"),
                 valueBoxOutput("totalRumahRusak")
               ),
               fluidRow(
                 box(title = "Grafik Jumlah Kejadian Bencana per Tahun", width = 12, status = "primary", solidHeader = TRUE,
                     plotlyOutput("grafikKejadian"))
               )
      ),
      tabPanel(title = tagList(icon("globe"), "Peta Interaktif"),
               leafletOutput("petaBencana", height = 600),
               br(),
               selectInput("tahun", "Pilih Tahun:", choices = 2010:2023, selected = 2023)
      ),
      tabPanel(title = tagList(icon("cloud-sun"), "Analisis Iklim"),
               plotlyOutput("grafikCurahHujan"),
               plotlyOutput("grafikTemperatur"),
               plotlyOutput("plot_korelasi_iklim"),
               plotlyOutput("boxplot_hujan"),
               plotlyOutput("boxplot_suhu")
      ),
      tabPanel(title = tagList(icon("chart-line"), "Analisis Statistik"),
               fluidRow(
                 box(title = "Input Variabel", width = 4, status = "primary", solidHeader = TRUE,
                     selectInput("xvar", "Variabel X:", choices = names(full_data)[c(3, 4)]),
                     selectInput("yvar", "Variabel Y:", choices = names(full_data)[c(5:15)]),
                     checkboxInput("run_lm", "Tampilkan Regresi Linier", value = TRUE),
                     checkboxInput("run_cor", "Tampilkan Korelasi", value = TRUE)
                 ),
                 box(title = "Plot & Hasil", width = 8, status = "info", solidHeader = TRUE,
                     plotOutput("stat_plot"),
                     verbatimTextOutput("stat_output")
                 )
               )
      ),
      tabPanel(title = tagList(icon("clock"), "Forecasting"),
               box(title = "Pengaturan Prediksi", width = 12, status = "info", solidHeader = TRUE,
                   sliderInput("tahun_prediksi", "Jumlah Tahun Prediksi ke Depan:", min = 1, max = 10, value = 5)),
               box(title = "Prediksi Jumlah Bencana", width = 12, status = "primary", solidHeader = TRUE,
                   plotOutput("plot_forecast"))
      ),
      tabPanel(title = tagList(icon("info-circle"), "Tentang"), includeMarkdown("about.md"))
    )
  )
)

server <- function(input, output, session) {
  filtered_data <- reactive({
    req(input$tahun, input$provinsi) # Pastikan input sudah tersedia
    
    data_to_filter <- full_data %>% filter(Year == input$tahun)
    
    # Jika bukan "SEMUA PROVINSI", filter lebih lanjut
    if (input$provinsi != "SEMUA PROVINSI") {
      data_to_filter <- data_to_filter %>% filter(Provinsi == input$provinsi)
    }
    
    data_to_filter
  })
  
  output$totalKejadian <- renderValueBox({
    total <- sum(filtered_data()$Bencana_jumlah, na.rm = TRUE)
    valueBox(formatC(total, format = "d", big.mark = ","), "Total Kejadian Bencana", icon = icon("exclamation-triangle"), color = "red")
  })
  
  output$totalKorban <- renderValueBox({
    total <- sum(filtered_data()$Meninggal, na.rm = TRUE)
    valueBox(formatC(total, format = "d", big.mark = ","), "Korban Meninggal", icon = icon("user-times"), color = "black")
  })
  
  output$totalRumahRusak <- renderValueBox({
    total <- sum(filtered_data()$`Rusak Berat`, na.rm = TRUE)
    valueBox(formatC(total, format = "d", big.mark = ","), "Rumah Rusak Berat", icon = icon("home"), color = "orange")
  })
  
  output$grafikKejadian <- renderPlotly({
    full_data %>%
      group_by(Year) %>%
      summarise(Total_Bencana = sum(Bencana_jumlah, na.rm = TRUE)) %>%
      plot_ly(x = ~Year, y = ~Total_Bencana, type = 'scatter', mode = 'lines+markers',
              line = list(color = 'firebrick')) %>%
      layout(title = "Tren Jumlah Bencana per Tahun",
             xaxis = list(title = "Tahun"),
             yaxis = list(title = "Jumlah Bencana"))
  })
  
  
  output$grafikCurahHujan <- renderPlotly({
    full_data %>%
      group_by(Year) %>%
      summarise(Hujan = mean(Curah_hujan, na.rm = TRUE)) %>%
      plot_ly(x = ~Year, y = ~Hujan, type = 'scatter', mode = 'lines+markers',
              line = list(color = 'blue')) %>%
      layout(title = "Rata-rata Curah Hujan Tahunan",
             xaxis = list(title = "Tahun"),
             yaxis = list(title = "Curah Hujan (mm/hari)"))
  })
  
  output$grafikTemperatur <- renderPlotly({
    full_data %>%
      group_by(Year) %>%
      summarise(Suhu = mean(Temp_mean, na.rm = TRUE)) %>%
      plot_ly(x = ~Year, y = ~Suhu, type = 'scatter', mode = 'lines+markers',
              line = list(color = 'orange')) %>%
      layout(title = "Rata-rata Suhu Tahunan",
             xaxis = list(title = "Tahun"),
             yaxis = list(title = "Suhu (°C)"))
  })
  
  output$plot_korelasi_iklim <- renderPlotly({
    df <- full_data %>%
      group_by(Year) %>%
      summarise(Hujan = mean(Curah_hujan, na.rm = TRUE),
                Bencana = sum(Bencana_jumlah, na.rm = TRUE))
    
    plot_ly(df, x = ~Hujan, y = ~Bencana, type = 'scatter', mode = 'markers',
            marker = list(size = 10, color = 'navy')) %>%
      layout(title = "Korelasi Curah Hujan vs Jumlah Bencana",
             xaxis = list(title = "Curah Hujan (mm/hari)"),
             yaxis = list(title = "Jumlah Bencana"))
  })
  
  output$boxplot_hujan <- renderPlotly({
    plot_ly(full_data, x = ~factor(Month), y = ~Curah_hujan, type = "box", color = ~factor(Month)) %>%
      layout(title = "Boxplot Curah Hujan Bulanan",
             xaxis = list(title = "Bulan"),
             yaxis = list(title = "Curah Hujan (mm/hari)"))
  })
  
  output$boxplot_suhu <- renderPlotly({
    plot_ly(full_data, x = ~factor(Month), y = ~Temp_mean, type = "box", color = ~factor(Month)) %>%
      layout(title = "Boxplot Suhu Bulanan",
             xaxis = list(title = "Bulan"),
             yaxis = list(title = "Suhu (°C)"))
  })
  
  output$petaBencana <- renderLeaflet({
    dat_tahun <- data_prov %>% filter(Tahun == input$tahun)
    prov_join <- prov_geo %>%
      mutate(Propinsi = toupper(trimws(Propinsi))) %>%
      left_join(dat_tahun, by = c("Propinsi" = "NAME_1"))
    
    pal <- colorNumeric(palette = "YlOrRd", domain = prov_join$`Jumlah Kejadian`, na.color = "transparent")
    
    leaflet(prov_join) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addPolygons(
        fillColor = ~pal(`Jumlah Kejadian`),
        fillOpacity = 0.7,
        color = "white",
        weight = 1,
        smoothFactor = 0.5,
        label = ~paste0(Propinsi, ": ", `Jumlah Kejadian`, " kejadian"),
        highlightOptions = highlightOptions(weight = 3, color = "#666", fillOpacity = 0.8, bringToFront = TRUE)
      ) %>%
      addLegend("bottomright", pal = pal, values = ~`Jumlah Kejadian`, title = "Jumlah Kejadian", opacity = 0.7)
  })
  
  observe({
    updateSelectInput(session, "xvar", choices = names(full_data)[c(3, 4)])
    updateSelectInput(session, "yvar", choices = names(full_data)[c(5:15)])
    provinsi_choices <- c("SEMUA PROVINSI", unique(full_data$Provinsi))
    updateSelectInput(session, "provinsi", choices = provinsi_choices, selected = "SEMUA PROVINSI")
  })
  
  output$stat_plot <- renderPlot({
    req(input$xvar, input$yvar)
    ggplot(full_data, aes_string(x = input$xvar, y = input$yvar)) +
      geom_point() +
      geom_smooth(method = if (input$run_lm) "lm" else "loess", se = FALSE) +
      theme_minimal()
  })
  
  output$stat_output <- renderPrint({
    req(input$xvar, input$yvar)
    results <- list()
    if (input$run_cor) {
      cor_test <- cor.test(full_data[[input$xvar]], full_data[[input$yvar]], method = "pearson")
      results$Korelasi <- cor_test
    }
    if (input$run_lm) {
      lm_model <- lm(as.formula(paste(input$yvar, "~", input$xvar)), data = full_data)
      results$Regresi <- summary(lm_model)
    }
    results
  })
  
  output$plot_forecast <- renderPlot({
    data_ts <- full_data %>%
      arrange(Year, Month) %>%
      mutate(tanggal = as.Date(paste(Year, Month, 1, sep = "-"))) %>%
      group_by(tanggal) %>%
      summarise(total = sum(Bencana_jumlah, na.rm = TRUE))
    
    ts_data <- ts(data_ts$total, start = c(year(min(data_ts$tanggal)), month(min(data_ts$tanggal))), frequency = 12)
    
    model <- auto.arima(ts_data, seasonal = TRUE)
    prediksi <- forecast(model, h = input$tahun_prediksi * 12)
    
    autoplot(prediksi) + 
      labs(title = "Prediksi Jumlah Kejadian Bencana (SARIMA)",
           x = "Waktu", y = "Jumlah Bencana") +
      theme_minimal()
  })
}

shinyApp(ui, server)
