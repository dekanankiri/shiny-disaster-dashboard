server <- function(input, output, session) {
  filtered_data <- reactive({
    req(input$tahun)
    full_data %>% filter(Year == input$tahun)
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
    leaflet(data = filtered_data()) %>%
      addTiles() %>%
      addCircleMarkers(~longitude, ~latitude,
                       label = ~paste("Bencana:", Bencana_jumlah),
                       color = "red", radius = 5, fillOpacity = 0.7)
  })
  
  observe({
    updateSelectInput(session, "xvar", choices = names(full_data)[c(3, 4)])
    updateSelectInput(session, "yvar", choices = names(full_data)[c(5:15)])
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
