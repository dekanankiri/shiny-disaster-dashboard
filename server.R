# ===================================================================
# server.R
#
# This script contains the server logic for the Shiny application.
# It defines how inputs are used to generate outputs (plots, tables, etc.).
# ===================================================================

server <- function(input, output, session) {
  
  # -- Reactive Data Filtering --
  filtered_data <- reactive({
    req(input$provinsi) # Ensure province input is available
    
    # Start with the full dataset
    data_to_filter <- full_data
    
    # Filter by province if a specific one is selected
    if (input$provinsi != "SEMUA PROVINSI") {
      data_to_filter <- data_to_filter %>% filter(Provinsi == input$provinsi)
    }
    
    data_to_filter
  })
  
  # -- Ringkasan Nasional Tab --
  output$totalKejadian <- renderValueBox({
    # Note: This summary should probably be national, regardless of province filter.
    # If it should react to the filter, use filtered_data(). For now, using full_data for national stats.
    total <- sum(full_data$Bencana_jumlah, na.rm = TRUE)
    valueBox(formatC(total, format = "d", big.mark = ","), "Total Kejadian Bencana (Nasional)", icon = icon("exclamation-triangle"), color = "red")
  })
  
  output$totalKorban <- renderValueBox({
    total <- sum(full_data$Meninggal, na.rm = TRUE)
    valueBox(formatC(total, format = "d", big.mark = ","), "Total Korban Meninggal (Nasional)", icon = icon("user-times"), color = "black")
  })
  
  output$totalRumahRusak <- renderValueBox({
    total <- sum(full_data$`Rusak Berat`, na.rm = TRUE)
    valueBox(formatC(total, format = "d", big.mark = ","), "Total Rumah Rusak Berat (Nasional)", icon = icon("home"), color = "orange")
  })
  
  output$grafikKejadian <- renderPlotly({
    full_data %>%
      group_by(Year) %>%
      summarise(Total_Bencana = sum(Bencana_jumlah, na.rm = TRUE)) %>%
      plot_ly(x = ~Year, y = ~Total_Bencana, type = 'scatter', mode = 'lines+markers', line = list(color = 'firebrick')) %>%
      layout(title = "Tren Jumlah Bencana per Tahun", xaxis = list(title = "Tahun"), yaxis = list(title = "Jumlah Bencana"))
  })
  
  # -- Peta Interaktif Tab --
  output$petaBencana <- renderLeaflet({
    req(input$tahun)
    dat_tahun <- data_prov %>% filter(Tahun == input$tahun)
    
    prov_join <- prov_geo %>%
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
  
  # -- Analisis Iklim Tab --
  output$grafikCurahHujan <- renderPlotly({
    filtered_data() %>%
      group_by(Year) %>%
      summarise(Hujan = mean(Curah_hujan, na.rm = TRUE)) %>%
      plot_ly(x = ~Year, y = ~Hujan, type = 'scatter', mode = 'lines+markers', line = list(color = 'blue')) %>%
      layout(title = paste("Rata-rata Curah Hujan Tahunan -", input$provinsi), xaxis = list(title = "Tahun"), yaxis = list(title = "Curah Hujan (mm/hari)"))
  })
  
  output$grafikTemperatur <- renderPlotly({
    filtered_data() %>%
      group_by(Year) %>%
      summarise(Suhu = mean(Temp_mean, na.rm = TRUE)) %>%
      plot_ly(x = ~Year, y = ~Suhu, type = 'scatter', mode = 'lines+markers', line = list(color = 'orange')) %>%
      layout(title = paste("Rata-rata Suhu Tahunan -", input$provinsi), xaxis = list(title = "Tahun"), yaxis = list(title = "Suhu (°C)"))
  })
  
  output$plot_korelasi_iklim <- renderPlotly({
    df <- filtered_data() %>%
      group_by(Year) %>%
      summarise(Hujan = mean(Curah_hujan, na.rm = TRUE), Bencana = sum(Bencana_jumlah, na.rm = TRUE))
    
    plot_ly(df, x = ~Hujan, y = ~Bencana, type = 'scatter', mode = 'markers', marker = list(size = 10, color = 'navy')) %>%
      layout(title = paste("Korelasi Curah Hujan vs Jumlah Bencana -", input$provinsi), xaxis = list(title = "Curah Hujan (mm/hari)"), yaxis = list(title = "Jumlah Bencana"))
  })
  
  output$boxplot_hujan <- renderPlotly({
    plot_ly(filtered_data(), x = ~factor(Month), y = ~Curah_hujan, type = "box", color = ~factor(Month)) %>%
      layout(title = paste("Boxplot Curah Hujan Bulanan -", input$provinsi), xaxis = list(title = "Bulan"), yaxis = list(title = "Curah Hujan (mm/hari)"), showlegend = FALSE)
  })
  
  output$boxplot_suhu <- renderPlotly({
    plot_ly(filtered_data(), x = ~factor(Month), y = ~Temp_mean, type = "box", color = ~factor(Month)) %>%
      layout(title = paste("Boxplot Suhu Bulanan -", input$provinsi), xaxis = list(title = "Bulan"), yaxis = list(title = "Suhu (°C)"), showlegend = FALSE)
  })
  
  # -- Analisis Statistik Tab --
  output$stat_plot <- renderPlot({
    req(input$xvar, input$yvar)
    ggplot(filtered_data(), aes_string(x = input$xvar, y = input$yvar)) +
      geom_point(alpha = 0.6, color = "dodgerblue") +
      geom_smooth(method = if (input$run_lm) "lm" else "loess", se = FALSE, color = "firebrick") +
      labs(title = paste("Analisis Statistik untuk", input$provinsi)) +
      theme_minimal()
  })
  
  output$stat_output <- renderPrint({
    req(input$xvar, input$yvar)
    data_for_stats <- filtered_data()
    results <- list()
    
    if (input$run_cor) {
      cat("--- Analisis Korelasi Pearson ---\n\n")
      cor_test <- cor.test(data_for_stats[[input$xvar]], data_for_stats[[input$yvar]], method = "pearson")
      results$Korelasi <- cor_test
    }
    
    if (input$run_lm) {
      cat("\n\n--- Ringkasan Model Regresi Linier ---\n\n")
      lm_model <- lm(as.formula(paste(input$yvar, "~", input$xvar)), data = data_for_stats)
      results$Regresi <- summary(lm_model)
    }
    
    print(results)
  })
  
  # -- Forecasting Tab --
  output$plot_forecast <- renderPlot({
    data_ts <- filtered_data() %>%
      arrange(Year, Month) %>%
      mutate(tanggal = as.Date(paste(Year, Month, 1, sep = "-"))) %>%
      group_by(tanggal) %>%
      summarise(total = sum(Bencana_jumlah, na.rm = TRUE))
    
    ts_data <- ts(data_ts$total, start = c(year(min(data_ts$tanggal)), month(min(data_ts$tanggal))), frequency = 12)
    
    model <- auto.arima(ts_data, seasonal = TRUE)
    prediksi <- forecast(model, h = input$tahun_prediksi * 12)
    
    autoplot(prediksi) +
      labs(
        title = paste("Prediksi Jumlah Kejadian Bencana (SARIMA) -", input$provinsi),
        subtitle = paste("Model ARIMA:", model),
        x = "Waktu", 
        y = "Jumlah Bencana"
      ) +
      theme_minimal()
  })
  
}