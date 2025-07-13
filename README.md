# Dasbor Analisis Bencana dan Iklim di Indonesia

Ini adalah dasbor interaktif yang dibangun menggunakan R dan Shiny untuk menganalisis dan memvisualisasikan data bencana hidrometeorologi serta hubungannya dengan data iklim (suhu dan curah hujan) di seluruh provinsi Indonesia.

## Tujuan Proyek

Dasbor ini bertujuan untuk menyediakan media analisis dan visualisasi data yang interaktif untuk mendukung eksplorasi dan pemahaman terhadap hubungan antara perubahan iklim dan bencana hidrometeorologi. Bencana hidrometeorologi mencakup peristiwa seperti banjir, tanah longsor, angin kencang, gelombang pasang, hingga kekeringan.

Dengan mengumpulkan dan mengintegrasikan data dari berbagai sumber, dasbor ini diharapkan dapat bermanfaat sebagai alat bantu dalam menjawab tantangan perubahan iklim di Indonesia bagi para pembuat kebijakan, akademisi, dan masyarakat umum.

## Fitur Utama

-   **Landing Page**: Halaman perkenalan yang ramah pengguna untuk menyambut dan memberikan gambaran umum tentang dasbor.

-   **Ringkasan Nasional**: Menampilkan statistik kunci dampak bencana secara nasional dalam *infobox* yang menarik.

-   **Peta Interaktif**: Visualisasi *choropleth* untuk sebaran jumlah kejadian bencana per provinsi yang dapat difilter berdasarkan tahun.

-   **Analisis Iklim**: Grafik tren untuk melihat perubahan suhu rata-rata dan curah hujan dari tahun ke tahun.

-   **Analisis Statistik**: Fitur untuk menganalisis korelasi dan regresi linear antara variabel iklim dan dampak bencana.

-   **Forecasting (Peramalan)**: Memprediksi jumlah kejadian bencana di masa depan menggunakan model SARIMA.

-   **Data Explorer**: Tabel data interaktif yang memungkinkan pengguna untuk mencari, menyaring, dan mengurutkan data mentah.

-   **Panduan Pengguna**: Halaman khusus yang berisi tutorial video dan panduan tekstual untuk menggunakan dasbor.

-   **Metadata**: Menyediakan informasi detail mengenai sumber dan definisi setiap variabel yang digunakan dalam analisis.

## Sumber Data

Dasbor ini menggunakan data dari beberapa sumber terpercaya:

-   **Data Kejadian Bencana**: [BNPB DIBI Dashboard](https://dibi.bnpb.go.id/superset/dashboard/1/?standalone=0&expand_filters=0 "null")

-   **Data Suhu Permukaan**: [ERA5 Land Monthly - Google Earth Engine](https://developers.google.com/earth-engine/datasets/catalog/ECMWF_ERA5_LAND_MONTHLY_AGGR "null")

-   **Data Curah Hujan**: [CHIRPS Daily - Google Earth Engine](https://developers.google.com/earth-engine/datasets/catalog/UCSB-CHG_CHIRPS_DAILY "null")

-   **Data Spasial Peta**: `indonesia-prov.geojson`

## Instalasi dan Menjalankan Aplikasi

Untuk menjalankan dasbor ini di komputer lokal Anda, ikuti langkah-langkah berikut:

#### 1. Prasyarat

-   Pastikan Anda telah menginstal **R** (versi 4.0 atau lebih baru).

-   Sangat disarankan untuk menggunakan **RStudio IDE**.

#### 2. Unduh atau Clone Repositori

Unduh semua file dari repositori ini dan letakkan dalam satu folder, atau clone repositori ini menggunakan Git:

```         
git clone https://github.com/dekanankiri/shiny-disaster-dashboard.git  
```

#### 3. Struktur Folder

Pastikan struktur folder proyek Anda sesuai dengan yang berikut:

```         
📁 PROYEK_DASHBOARD/    ├── 📄 landing.R    ├── 📁 data/    │   ├── 📊 DataKomstat_Gabung.xlsx    │   └── 📊 DataKomstat_Provinsi.xlsx    └── 📁 www/        ├── 🖼️ logo.png        └── 🗺️ indonesia-prov.geojson  
```

#### 4. Instal Pustaka (Packages) yang Dibutuhkan

Buka file `app.R` di RStudio. Jalankan perintah berikut di konsol R untuk menginstal semua pustaka yang diperlukan:

```         
install.packages(c(   "shiny", "shinydashboard", "shinyjs", "leaflet", "tidyverse",    "plotly", "readxl", "forecast", "ggfortify", "sf",    "shinycssloaders", "DT", "markdown" ))  
```

#### 5. Jalankan Aplikasi

Setelah semua pustaka terinstal, klik tombol **"Run App"** yang muncul di bagian atas editor RStudio, atau jalankan perintah berikut di konsol:

```         
shiny::runApp()  
```

Aplikasi akan terbuka di jendela baru atau di browser default Anda.
