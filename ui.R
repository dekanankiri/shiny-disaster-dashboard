ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = span("Dashboard Bencana & Iklim Indonesia", style = "font-weight: bold; font-size: 20px; color: white")),
  dashboardSidebar(
    tags$head(tags$style(HTML('body, label, input, button, select { font-family: "Segoe UI", sans-serif; }'))),
    selectInput("tahun", "Pilih Tahun:", choices = 2010:2023, selected = 2023),
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
               leafletOutput("petaBencana", height = 600)
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
