# TFM VIU Master en Big data y Data Science (2023)
# Autor: Francisco González Andrade

# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/

# Librería usada para establecer la conexión a una BBDD
#library(odbc)

library(xlsx)
library(readxl)
library(zoo)
library(tidyr)
library(dplyr)
library(lubridate)
library(arules)
library(arulesViz)
library(shiny)
library(shinythemes)
library(shinyWidgets)
library(bslib)
library(leaflet)
library(plotly)
library(rpivotTable)
library(forecast)
library(recommenderlab)
library(DT)
library(corrplot)
library(shinydashboard)

fecha_actual <- Sys.Date()

# Código para una conexión y obtención de datos desde BBDD SQL Serverlocal (comentado tras subir subir la app a la nube)
# Definir los parámetros de la conexión y establecer la conexión
# server <- "LAPTOP-KU29CVSF\\SQLEXPRESS"
# database <- "TFM"
# con <- dbConnect(odbc(), driver = "SQL Server",  server = server, database = database, trusted_connection = "yes")

# CARGA DE DATOS #
# Realizamos las consultas a la base de datos para cargar las dimensiones y hechos
# DimSubfamilia <- dbGetQuery(con, "SELECT SubfamiliaID, Descripcion FROM dbo.Subfamilia")
# DimFamilia <- dbGetQuery(con, "SELECT FamiliaID, Descripcion FROM dbo.Familia")
# DimActividad <- dbGetQuery(con, "SELECT ActividadID, Descripcion FROM dbo.Actividad")
# DimSucursal <- dbGetQuery(con, "SELECT SucursalID, Nombre, Latitud, Longitud FROM dbo.Sucursal")
# DimTiempo <- dbGetQuery(con, "SELECT Fecha, Año, Mes, Nombre_mes, Dia, Dia_semana, Semana, Trimestre, Temporada, Dia_laborable FROM dbo.Tiempo")
# DimArticulo <- dbGetQuery(con, "SELECT Codigo, Nombre, FamiliaID, SubfamiliaID, Genera_retal, Formato, Tipo_impositivo, Num_medidas, Largo, Ancho, Coeficiente, Peso_bruto, Peso_neto, Categoria, Peso_unidad FROM dbo.Articulo")
# DimPersonal <- dbGetQuery(con, "SELECT E.EmpleadoID, Fecha_nacimiento, Genero, Nivel_estudios, Puesto, Departamento, Tipo_contrato, Jornada, Salario, Fecha_contratacion FROM dbo.Empleado E inner join dbo.Contratacion as C on E.EmpleadoID = C.EmpleadoID")
# DimCliente <- dbGetQuery(con, "SELECT ClienteID, Nombre, Fecha_creacion, Forma_juridica, Cod_postal, Provincia, Pais, Tipo_cliente, Ultima_compra, Descuento, RepresentanteID, Credito_activo, ActividadID, Bloqueado, Tarifa, Tarifas_especiales, Total_autorizado, Riesgo_asegurado, Riesgo, Canal_cobro, 
#                               CASE WHEN CHARINDEX(' ', forma_pago) > 0 THEN SUBSTRING(forma_pago, 1, CHARINDEX(' ', forma_pago) - 1) ELSE forma_pago END AS Metodo_pago,
#                               CASE WHEN PATINDEX('%[0-9]%', forma_pago) > 0 THEN SUBSTRING(forma_pago, PATINDEX('%[0-9]%', forma_pago), CHARINDEX(' ', forma_pago + ' ', PATINDEX('%[0-9]%', forma_pago)) - PATINDEX('%[0-9]%', forma_pago)) ELSE '0'
#                               END AS Dias_pago, Latitud, Longitud FROM dbo.Cliente where (clienteid not between '90000' and '90007') and fecha_creacion < '2023-01-01'")
# 
# FactVentas <- dbGetQuery(con, "SELECT FacturaID, SucursalID, Isla, ClienteID, Tipo_documento, Num_factura, Fecha_factura, Hora_factura, ArticuloID, Unidades_articulo, V.Precio_venta, V.Precio_coste, V.Precio_liquido, Descuento, Clase_articulo, Tarifa, VendedorID, Impuesto, Desviacion, Causa_FR, 
# 	                             Unidades_articulo * V.Precio_liquido as Importe_linea, Unidades_articulo * V.Precio_coste as Coste_linea, Unidades_articulo * A.Peso_unidad as Peso_linea, (Unidades_articulo * V.Precio_liquido) - (Unidades_articulo * V.Precio_coste) as Margen_bruto 
# 	                             FROM dbo.Ventas V left join dbo.Articulo A on codigo = articuloid")
#dbDisconnect(con)

##########################################################################################################

# Cargar datos de fuentes externas (archivos excel)
# Historico ventas de cemento desde ISTAC
ISTAC_cemento <-   read.xlsx2("ISTAC_cemento.xlsx", sheetName = "Sheet0", startRow = 6 , colIndex = c(1,2,7,12,17,22,27,32,37), stringsAsFactors=FALSE)
# Corregimos el título de las columnas y las fechas de la primera columna
colnames(ISTAC_cemento) <- c("Fecha", sub("\\ES.*", "", gsub('[.]', '', colnames(ISTAC_cemento)))[2:ncol(ISTAC_cemento)])
ISTAC_cemento <- ISTAC_cemento[c(2:nrow(ISTAC_cemento)),]
colnames(ISTAC_cemento) <- c("Fecha", sub("\\ES.*", "", gsub('[.]', '', colnames(ISTAC_cemento)))[2:ncol(ISTAC_cemento)]) 
ISTAC_cemento[,1] <- sub(".*\\(", "", gsub('[M)]', '', ISTAC_cemento[,1])) #nos quedamos con el string referente a la fecha
ISTAC_cemento <- subset(ISTAC_cemento, nchar(ISTAC_cemento$Fecha)>4, select = colnames(ISTAC_cemento[, !names(ISTAC_cemento) %in% c("Canarias")])) #se eliminan las filas con el total por año
ISTAC_cemento[,2:ncol(ISTAC_cemento)] <- as.double(unlist(ISTAC_cemento[,2:ncol(ISTAC_cemento)])) #convertimos datos numéricos
ISTAC_cemento <- na.omit(ISTAC_cemento)

# Serie histórica de ventas de los últimos 12 años
Historico_ventas <- read.xlsx2("seriehistorica_ventas.xlsx", sheetName = "Hoja1", colClasses = c("numeric", "numeric", "numeric", "numeric"))
Historico_agrupado <- aggregate(VENTAS ~ AÑO + MES, data = Historico_ventas, sum)
Historico_agrupado <- Historico_agrupado[order(Historico_agrupado$AÑO, Historico_agrupado$MES), ]

# Cargar datos internos desde excel en la nube tras despliegue
DimActividad <- read_excel("DimActividad.xlsx", sheet = "Sheet1")
DimFamilia <- read_excel("DimFamilia.xlsx", sheet = "Sheet1")
DimSubfamilia <- read_excel("DimSubfamilia.xlsx", sheet = "Sheet1")
DimSucursal <- read_excel("DimSucursal.xlsx", sheet = "Sheet1", col_types = c("numeric", "text", "numeric", "numeric"))
DimPersonal <- read_excel("DimPersonal.xlsx", sheet = "Sheet1", col_types = c("text", "text", "text", "text", "text", "text", "text", "text", "numeric", "text"))

DimTiempo <- read_excel("DimTiempo.xlsx", sheet = "Sheet1", 
                        col_types = c("text", "numeric", "numeric", "text", "numeric", 
                                      "text", "numeric", "numeric", "text", "logical"))

DimArticulo <- read_excel("DimArticulo.xlsx", sheet = "Sheet1", 
                          col_types = c("text", "text", "text", "text", "numeric", 
                                        "text", "text", "numeric", "numeric", "numeric", 
                                        "numeric", "numeric", "numeric", "text", "numeric"))

DimCliente <- read_excel("DimCliente.xlsx", sheet = "Sheet1", 
                         col_types = c("text", "text", "text", "text", "text", "text", 
                                       "text", "text", "text", "numeric", "text", "logical", 
                                       "text", "logical", "numeric", "text", "numeric", 
                                       "numeric", "numeric", "text", "text", "text", "numeric", 
                                       "numeric"))

FactVentas <- read_excel("FactVentas.xlsx", sheet = "Sheet1", 
                         col_types = c("text", "numeric", "text", "text", "text", 
                                       "numeric", "text", "text", "text", "numeric", 
                                       "numeric", "numeric", "numeric", "numeric", 
                                       "text", "text", "text", "numeric", "numeric", 
                                       "text", "numeric", "numeric", "numeric", "numeric"))


# Se realizan las conversiones de datos necesarias
DimPersonal$Fecha_nacimiento <- as.Date(DimPersonal$Fecha_nacimiento)
DimPersonal$Fecha_contratacion <- as.Date(DimPersonal$Fecha_contratacion)

DimCliente$Fecha_creacion <- as.Date(DimCliente$Fecha_creacion)
DimCliente$Ultima_compra <- as.Date(DimCliente$Ultima_compra)
DimCliente$Dias_pago <- as.numeric(DimCliente$Dias_pago)

DimTiempo$Fecha <- as.Date(DimTiempo$Fecha)

FactVentas$Fecha_factura <- as.Date(FactVentas$Fecha_factura)


# TRANSFORMACIONES #
# Calcular la edad y la antigüedad para la dimensión Personal
DimPersonal$Edad <- floor(as.numeric(difftime(fecha_actual, DimPersonal$Fecha_nacimiento, units = "days")) / 365.25)
DimPersonal$Antiguedad <- floor(as.numeric(difftime(fecha_actual, DimPersonal$Fecha_contratacion, units = "days")) / 365.25)

# Calcular el margen sobre ventas y sobre coste en porcentaje
FactVentas$Margenven_percent <- 1- FactVentas$Coste_linea / FactVentas$Importe_linea
FactVentas$Margencos_percent <- (FactVentas$Importe_linea / FactVentas$Coste_linea) - 1


# Sumatorio de importe_linea por año y cliente
Ventas_cliente <- FactVentas %>%
  group_by(ClienteID) %>%
  summarise(Importe_ventas2021 = sum(Importe_linea[year(Fecha_factura) == 2021]),
            Importe_ventas2022 = sum(Importe_linea[year(Fecha_factura) == 2022]))

# Sumatorio de Margen_bruto por año y cliente
Margen_cliente <- FactVentas %>%
  group_by(ClienteID) %>%
  summarise(Margen2021 = sum(Margen_bruto[year(Fecha_factura) == 2021]),
            Margen2022 = sum(Margen_bruto[year(Fecha_factura) == 2022]))

# Calculo de importe medio de las ventas por cliente
Importemedio_cliente <- FactVentas %>%
  filter(Tipo_documento == 'F') %>%
  group_by(ClienteID) %>%
  summarise(Importe_medio_cliente = mean(sum(Importe_linea) / n_distinct(FacturaID)))

# Calculo del numero de ventas y devoluciones por año 2021 y 2022 por cliente
Numventas_cliente <- FactVentas %>%
  filter(Tipo_documento == 'F') %>%
  mutate(Año = year(Fecha_factura)) %>%
  group_by(ClienteID, Año) %>%
  summarise(Numventas = n_distinct(FacturaID)) %>%
  pivot_wider(names_from = Año, values_from = Numventas, names_prefix = "Numventas") %>%
  replace_na(list(`Numventas2021` = 0, `Numventas2022` = 0))

Numdevoluciones_cliente <- FactVentas %>%
  filter(Tipo_documento == 'FR') %>%
  mutate(Año = year(Fecha_factura)) %>%
  group_by(ClienteID, Año) %>%
  summarise(Numdevoluciones = n_distinct(FacturaID)) %>%
  pivot_wider(names_from = Año, values_from = Numdevoluciones, names_prefix = "Numdevoluciones") %>%
  replace_na(list(`Numdevoluciones2021` = 0, `Numdevoluciones2022` = 0))


# Agregar las columnas al dataframe DimCliente y sustituir por 0 los valores NA's introducidos
DimCliente <- DimCliente %>%
  left_join(Ventas_cliente, by = c("ClienteID" = "ClienteID")) %>%
  left_join(Margen_cliente, by = c("ClienteID" = "ClienteID")) %>%
  left_join(Numventas_cliente, by = "ClienteID") %>%
  left_join(Numdevoluciones_cliente, by = "ClienteID") %>%
  left_join(Importemedio_cliente, by = "ClienteID") %>%
  mutate_at(vars(starts_with("Numventas")), ~coalesce(., 0)) %>%
  mutate_at(vars(starts_with("Numdevoluciones")), ~coalesce(., 0)) %>%
  mutate_at(vars(starts_with("Importe_")), ~coalesce(., 0)) %>%
  mutate_at(vars(starts_with("Margen")), ~coalesce(., 0))

# Calculamos la columna Recencia (cuan recientemente nos compra el cliente)
DimCliente <- DimCliente %>%
  mutate(Recencia = case_when(
    Ultima_compra >= fecha_actual - months(4) ~ "Muy reciente",
    Ultima_compra >= fecha_actual - months(11) ~ "Reciente",
    Ultima_compra >= fecha_actual - months(20) ~ "Menos reciente",
    Ultima_compra < fecha_actual - months(20) ~ "Antiguo",
    is.na(Ultima_compra) ~ "Sin compras"
  )
  )

# INTERACTIVE MAP #
# Calculamos el dataframe para el mapa de clientes
dfmapventas <- FactVentas %>%
  group_by(ClienteID) %>%
  summarise(Importe_ventas = round(sum(Importe_linea[year(Fecha_factura) == 2022]), 0) )

dfmapventas <- merge(subset(DimCliente, !is.na(Latitud), select=c(ClienteID, Latitud, Longitud)), dfmapventas, by = "ClienteID", all.x = TRUE)
dfmapventas <- dfmapventas[order(dfmapventas$Importe_ventas, decreasing = TRUE), ]
#############################

# PURCHASE ANALYSIS #
# Calculamos el objeto transacciones
dftransac <- subset(FactVentas, Tipo_documento == "F", select = c(FacturaID, ArticuloID))

dftransac$FacturaID <- as.factor(dftransac$FacturaID)
dftransac$ArticuloID <- as.factor(dftransac$ArticuloID)

dftransac <- dftransac %>%
  group_by(FacturaID) %>%
  summarize(ArticuloID = paste(ArticuloID, collapse = ",")) %>%
  ungroup()

dftransac$FacturaID <- NULL
colnames(dftransac) <- c("Articulos")
lista_articulos <- strsplit(dftransac$Articulos, split = ",")

# Crear el objeto de transacciones y eliminar las variables auxiliares
transac <- as(lista_articulos, "transactions")
rm(dftransac)
rm(lista_articulos)


# Recommender Popular y UBCF
#Se filtra el subgrupo de clientes sobre el que actuar, se crea la matriz de ventas y se aplican los métodos
ven <- as.data.frame(FactVentas[FactVentas$Tipo_documento == 'F' & year(FactVentas$Fecha_factura) == 2022, c("ClienteID", "ArticuloID")] )
clibyact <- subset(DimCliente, substr(ActividadID, 1, 1) != "2", select = c(ClienteID))
venbyact <- ven[ven$ClienteID %in% clibyact$ClienteID, ]

dfrecomend <- data.frame(Cliente = unique(venbyact$ClienteID))
dfrecomend <- dfrecomend %>% arrange(Cliente)
 
matriz_ventas <- venbyact %>% as("realRatingMatrix")

modelopop <- Recommender(matriz_ventas, method = "POPULAR")
recomendpop <- predict(modelopop, matriz_ventas, n = 5, type = "topNList")

modeloubcf <- Recommender(matriz_ventas, method = "UBCF")
recomendubcf <- predict(modeloubcf, matriz_ventas, n = 5, type = "topNList")
######################


### SHINY APP ###
# Se define la UI para la aplicación
ui <- fluidPage(
    useShinydashboard(),
    # Application title
    titlePanel(title=div(img(src="logoviu.jpg", height = "3%", width = "4%"), "Máster en Big Data y Data Science 2023")),
    theme = shinytheme("cerulean"),
    navbarPage(title = "Shiny-Biz",
               tabPanel(title = "Sales", 
                        fluidRow(
                          column(7,
                                 selectInput("seleccion_sucursalhorario", "Selecciona la sucursal:", choices=append("TODAS", DimSucursal$Nombre ) ),
                                 plotlyOutput("Plot_tramoshorasfacturacion", height = "335px"), br()
                          ),
                          column(5, plotlyOutput("Plot_gauge"))
                        ), br(),
                        fluidRow(
                          column(7, 
                                 column(12, h3("Comparativa ventas cemento (ISTAC) vs facturación")),
                                 column(6, h4("Datos ISTAC"),
                                        selectInput("VEN_cemento_islas", "Islas:", sort(unique(colnames(ISTAC_cemento[, !names(ISTAC_cemento) %in% c("Fecha", "Canarias")]))), selected = c(""), multiple = TRUE)),
                                 column(6, h4("Datos Empresa"),
                                        selectInput("VEN_fact_sucursales", "Sucursales:", sort(unique(DimSucursal$Nombre)), selected = c(""), multiple = TRUE)
                                 ),
                                 column(12, plotlyOutput("Plotly_cementovsfact")) 
                          ),
                          column(5, br(), br(), br(), br(),
                                 plotOutput("corrplotOutput")
                          )
                        ),br(),
                        fluidRow(
                          column(12,
                                 plotOutput("Plot_forecast", height = "480px")
                          )
                        )
               ),
               tabPanel(title = "Purchase analysis",
                        fluidRow(
                          column(4, 
                                 h3("Análisis de la cesta de la compra (Apriori)"),
                                 plotOutput("Plot_marketbasket")),
                          column(5, br(), br(),
                                 dataTableOutput("reglasTable")
                          ),
                          column(3, br(), br(),
                                 plotOutput("reglasgraph")
                          )
                        ), br(),
                        fluidRow(
                          column(6, 
                                 h3("Recommender POPULAR"),
                                 dataTableOutput("recommenderpopular") ),
                          column(6, 
                                 h3("Recommender UBCF"),
                                 dataTableOutput("recommenderubcf")
                          )
                        ), br(), br()
               ),
               tabPanel(title = "Customers and Products",
                        fluidRow(
                          column(6, plotlyOutput("Plot_funnel_clientes")),
                          column(6, plotlyOutput("Plot_funnel_productos"))
                        ), br(),
                        fluidRow(
                          column(6, plotlyOutput("treemap_actividad", width = "100%", height = 500)),
                          column(6, plotlyOutput("treemap_familias"))
                        )
               ),
               tabPanel(title = "Interactive Map",
                        fluidRow(
                          column(12, 
                                 h3("Localización de los clientes con mayor importe de ventas"),
                                 leafletOutput("map", width = "100%", height = 700))
                        )
               ),
               tabPanel(title = "Explorer",
                        fluidRow(
                          column(12, rpivotTableOutput("Pivot_explorador"))
                        )
               ),
               tabPanel(title = "HHRR",
                        fluidRow(
                          column(4, infoBoxOutput('infoboxedadmedia', width = 12)),
                          column(4, infoBoxOutput('infoboxantiguedad', width = 12)),
                          column(4, infoBoxOutput('infoboxsalario', width = 12))
                        ), br(), br(), br(),
                        fluidRow(
                          column(4, plotlyOutput("donutchart")),
                          column(8, plotlyOutput("Plot_antiguedad_salario"))
                        )
               ),
               inverse = T
    )
)

# Se define la lógica requerida en la parte server
server <- function(input, output) {
  
  # Dentro del server, se especifica cada una de las funciones que calculan y realizan la visualización
  
  # SALES #
  # Procesamiento y cálculo para la gráfica de barras horario de facturación 
  dfhorario_facturacion <- reactive ({
    
    Horario_fact <- FactVentas[FactVentas$Hora_factura > "06:00:00.0000000" & FactVentas$Hora_factura < "16:00:00.0000000" & FactVentas$Tipo_documento == 'F', c("SucursalID", "Hora_factura", "Importe_linea")]
    Horario_fact$Hora_factura <- substr(Horario_fact$Hora_factura, 1, 5)
    
    SUC <- input$seleccion_sucursalhorario
    
    if (SUC == "TODAS"){       
      df <- Horario_fact %>% group_by(Hora_factura) %>% summarize(Facturacion_total= round(sum(Importe_linea), 0)) %>% as.data.frame()
    } else {
      id_encontrado <- unique(subset(DimSucursal, Nombre == SUC)$SucursalID)
      df <- subset(Horario_fact, SucursalID == id_encontrado, select = c(Hora_factura, Importe_linea))
      df <- df %>% group_by(Hora_factura) %>% summarize(Facturacion_total= round(sum(Importe_linea), 0)) %>% as.data.frame()
    }
    df
  })
  
  # Visualización gráfico horario de facturación
  output$Plot_tramoshorasfacturacion <- renderPlotly({
    df <- dfhorario_facturacion()
    
    p <- plot_ly(df, x = df$Hora_factura, y = df$Facturacion_total, type = 'bar', hovertext =~paste(df$Facturacion_total, "€"), hoverinfo = "text") %>% # hovertemplate = "%{y:.0f} €") %>%
      layout(margin = list(r = 35), title = "Tramos de facturación por horas", yaxis = list(title = "", fixedrange=TRUE), xaxis = list(title = "", tickangle = 25, fixedrange=TRUE)) %>% config(displayModeBar = F)
    p
  })
  
  # Visualización gráfico acelerómetro
  output$Plot_gauge <- renderPlotly({
    
    fig <- plot_ly(
      domain = list(x = c(0, 1), y = c(0, 1)),
      value = 2257500,
      title = list(text = "Objetivo de beneficios 2023"),
      type = "indicator",
      mode = "gauge+number+delta",
      delta = list(reference = sum(subset(FactVentas, Fecha_factura > "2021-12-31" & Fecha_factura < "2022-06-01", select = c(Margen_bruto))) ),
      gauge = list(
        axis =list(range = list(NULL, 6500000)),
        steps = list(
          list(range = c(0, 3000000), color = "red"),
          list(range = c(3000000, 4800000), color = "yellow"),
          list(range = c(4800000, 6500000), color = "lightgreen")),
        bar = list(color = "black")
      )) 
    fig <- fig %>%
      layout(margin = list(t=50, l=20,r=30)) %>% config(displayModeBar = F)
    
    fig
    
  })
  
  # Visualización predicción realizada con forecast y ARIMA
  output$Plot_forecast <- renderPlot({
    # Crear una serie de tiempo para las ventas
    Serie_historica <- ts(Historico_agrupado$VENTAS, start = c(2011, 1), frequency = 12)
    train <- window(Serie_historica, end = c(2022, 12))
    
    # Ajustar un modelo ARIMA a los datos
    modelo <- auto.arima(train)
    
    # Realizar la predicción para el año 2023
    prediccion <- forecast(modelo, 12, level=95)
    
    valores_2023 <- window(Serie_historica, start = c(2023, 1), end = c(2023, 5))
    
    pronostico <- prediccion$mean
    # Calcular el error cuadrado entre el pronóstico y los valores reales de 2023
    error_cuadrado <- (pronostico - valores_2023)^2
    rmse <- sqrt(mean(error_cuadrado))
    
    # Graficar la predicción, los valores de la serie histórica para 2023 y el RMSE calculado
    plot(prediccion, main = "Pronóstico con auto.arima")
    lines(valores_2023, col = "red")
    legend("topleft", legend = c("Histórico hasta 2022", "Valores en 2023"),
           col = c("black", "red"), lwd = c(1, 2), bty = "n")
    text(x = 2023, y = 600000, 
         labels = paste("RMSE:", round(rmse, 1)), pos = 3, cex = 1.5)
    
  })
  
  
  # Función reactiva para procesar y ajustar las ventas de la empresa y las ventas de cemento en peso
  react_ISTACcementovsfact <- reactive({
    if (is.null(input$VEN_fact_sucursales)){
      suc_buscar <- unique(DimSucursal$Nombre)
    }else{
      suc_buscar <- input$VEN_fact_sucursales
    }
    
    if (is.null(input$VEN_cemento_islas)){
      islas_buscar <- colnames(ISTAC_cemento[, !names(ISTAC_cemento) %in% c("Fecha")])
    }else{
      islas_buscar <- input$VEN_cemento_islas
    }
    
    df_cemento <- subset(ISTAC_cemento, select = c("Fecha", islas_buscar))
    df_cemento$KG_CEM <- rowSums(subset(df_cemento, select = islas_buscar), na.rm = TRUE)
    df_cemento$KG_CEM <- df_cemento$KG_CEM * 1000
    
    df_cemento <- subset(df_cemento, select = c("Fecha", "KG_CEM"))
    df_cemento$Fecha <- as.Date(as.yearmon(df_cemento$Fecha))
    
    id_encontrado <- unique(subset(DimSucursal, Nombre %in% suc_buscar)$SucursalID)
    df_ventas <- subset(FactVentas, SucursalID %in% id_encontrado, select = c(Fecha_factura, Peso_linea))
    df_ventas <- merge(df_ventas, DimTiempo, by.x = "Fecha_factura", by.y = "Fecha", all.x = TRUE)
    df_ventas$Mes <- sprintf("%02d", df_ventas$Mes)
    
    df_ventas$Fecha <- paste0(df_ventas$Año, "-", df_ventas$Mes)
    df_ventas <- df_ventas %>% group_by(Fecha) %>% summarise(KG_VENTAS= round(sum(Peso_linea, na.rm=TRUE), 2 ) )
    df_ventas$Fecha <- as.Date(as.yearmon(df_ventas$Fecha))
    
    df <- merge(df_cemento, subset(df_ventas, Fecha <= max(df_cemento$Fecha)),by = c("Fecha"), all.x = TRUE)
    df <- subset(df, year(Fecha) >= min(year(FactVentas$Fecha_factura)) )
    
    df
  })
  
  # Visualización de la gráfica de líneas Comparativa de correlación de variables
  output$Plotly_cementovsfact <- renderPlotly({
    #Se llama a la función reactiva especificada anteriormente
    df <- react_ISTACcementovsfact()
    
    ay1 <- list(showgrid = FALSE, title="Kilos ventas", tickfont = list(color = "blue"), titlefont = list(color ="blue"))
    ay2 <- list(showgrid = FALSE, tickfont = list(color = "salmon"), title="Kilos ISTAC", titlefont = list(color ="salmon"), overlaying = "y", side = "right", hoverformat= ",1")
    
    p <- plot_ly(df, x = df$Fecha, y = df$KG_CEM, name = "Cemento", type="scatter", mode = "lines+markers", line = list(color = "salmon"), marker = list(color = "salmon" ), text = paste0("Kg: ", df$KG_CEM, "; Fecha: ", substr(as.character(df$Fecha),1,7) ), hoverinfo = "text", yaxis = "y2" ) %>%
      add_trace(x = df$Fecha,  y = df$KG_VENTAS, name = "Facturación",  type = "scatter", mode = "lines+markers", line = list(color = "blue"), marker = list(color = "blue" ), text = paste0("Kg: ", df$KG_VENTAS, "; Fecha: ", substr(as.character(df$Fecha),1,7) ), hoverinfo = "text", yaxis = "y1" ) %>%
      
      layout(margin = list(r = 45), title="ISTAC cemento vs kilos facturados", showlegend = T, legend = list(orientation = "h", xanchor = "center", x = 0.5), xaxis = list(title = " ", categoryarray = ~Fecha, categoryorder = "array"), yaxis = ay1 , yaxis2 = ay2 )  %>%
      config(displayModeBar = F)
    p
  })
  
  # Visualización del gráfico de correlación
  output$corrplotOutput <- renderPlot({
    df <- react_ISTACcementovsfact()
    correlation_matrix <- cor(df[, c("KG_CEM", "KG_VENTAS")], use = "complete.obs")
    title <- paste("Valor de correlación:", round (correlation_matrix[2][1], 3))
    p <- corrplot(correlation_matrix, method = "circle", title = title, tl.col = "black", tl.srt = 45, mar=c(0,0,1,0))
    
    p
    
  })
  
  # PURCHASE ANALYSIS #
  # Visualización de los artículos más frecuentes
  output$Plot_marketbasket <- renderPlot({
    
    p <- itemFrequencyPlot(transac,topN=20,type="absolute")
    
    p
    
  })
  
  # Visualización de la tabla creada para las reglas de asociación con Apriori (Market basket analysis)
  output$reglasTable <- renderDataTable({
    
    #Aplicamos el algoritmo apriori teniendo como parámetros
    #soporte mínimo = 0.001
    #confianza mínima = 0.1
    #tamaño máximo = 10
    reglas.asociacion <- apriori(transac, parameter = list(supp=0.001, conf=0.1, maxlen=10))
    
    # Ordenar las reglas por confianza descendente
    reglas_ordenadas <- sort(reglas.asociacion, by = "confidence", decreasing = TRUE)
    
    # Convertir las reglas a un dataframe
    df_reglas <- as(reglas_ordenadas, "data.frame")
    df_reglas <- head(df_reglas, 20)
    
    # Retornar la tabla
    datatable(df_reglas, class = 'row-border stripe compact hover', rownames= F, selection = 'single',
              options = list(paging = T, lengthChange=F, pageLength=10, searching=T, info=F)) %>% 
      formatRound(c(2,3,4,5), digits=3)
    
  })
  
  # Visualización grafo de reglas de asociación con Apriori (Market basket analysis)
  output$reglasgraph <- renderPlot({
    
    #Aplicamos el algoritmo apriori teniendo como parámetros
    #soporte mínimo = 0.001
    #confianza mínima = 0.1
    #tamaño máximo = 10
    reglas.asociacion <- apriori(transac, parameter = list(supp=0.001, conf=0.1, maxlen=10))
    
    # Ordenar las reglas por confianza descendente
    reglas_ordenadas <- sort(reglas.asociacion, by = "confidence", decreasing = TRUE)
    
    # Convertir las reglas a un dataframe
    plot(reglas_ordenadas, method = "graph", limit = 20)
    
  })
  
  # Visualización de la tabla para el sistema de recomendación (método POPULAR)
  output$recommenderpopular <- renderDataTable({
    
    #Se descompone el resultado para representarlo
    recomen <- as(recomendpop, "list")
    dfrecomendpop <- dfrecomend
    
    for (j in 1:nrow(dfrecomendpop)) {
      dfrecomendpop$Recomendacion1[j] <- recomen[[j]][1]
      dfrecomendpop$Recomendacion2[j] <- recomen[[j]][2]
      dfrecomendpop$Recomendacion3[j] <- recomen[[j]][3]
      dfrecomendpop$Recomendacion4[j] <- recomen[[j]][4]
      dfrecomendpop$Recomendacion5[j] <- recomen[[j]][5]
    }
    
    # Retornar la tabla
    datatable(dfrecomendpop, class = 'row-border stripe compact hover', rownames= F, selection = 'single',
              options = list(paging = T, lengthChange=F, pageLength=10, searching=T, info=F))
    
  })
  
  # Visualización de la tabla para el sistema de recomendación (método UBCF)
  output$recommenderubcf <- renderDataTable({
    
    #Se descompone el resultado para representarlo
    recomen <- as(recomendubcf, "list")
    dfrecomendubcf <- dfrecomend
    
    for (j in 1:nrow(dfrecomendubcf)) {
      dfrecomendubcf$Recomendacion1[j] <- recomen[[j]][1]
      dfrecomendubcf$Recomendacion2[j] <- recomen[[j]][2]
      dfrecomendubcf$Recomendacion3[j] <- recomen[[j]][3]
      dfrecomendubcf$Recomendacion4[j] <- recomen[[j]][4]
      dfrecomendubcf$Recomendacion5[j] <- recomen[[j]][5]
    }
    
    # Retornar la tabla
    datatable(dfrecomendubcf, class = 'row-border stripe compact hover', rownames= F, selection = 'single',
              options = list(paging = T, lengthChange=F, pageLength=10, searching=T, info=F))
    
  })
  
  
  # CUSTOMERS AND PRODUCTS #
  # Visualización funnel de clientes que incluye las transformacioens previas realizadas
  output$Plot_funnel_clientes <- renderPlotly({
    total_clientes <- length(DimCliente$ClienteID)
    
    ventas_2022 <- subset(FactVentas, year(Fecha_factura)==2022, select = c(ClienteID))
    ventas_6m <- subset(FactVentas, year(Fecha_factura)==2022 & month(Fecha_factura) > 6, select = c(ClienteID))
    
    # Realizar el conteo de clientes distintos
    clientes_ventas <- length(unique(FactVentas$ClienteID))
    clientes_ventas2022 <- length(unique(ventas_2022$ClienteID))
    clientes_6m <- length(unique(ventas_6m$ClienteID))
    
    etapas <- c("Clientes dados de alta", "Clientes ventas 2021 y 2022", "Clientes ventas sólo en 2022", "Clientes ventas ultimos 6 meses")
    valores <- c(total_clientes, clientes_ventas, clientes_ventas2022, clientes_6m)
    
    # Crear el dataframe
    df <- data.frame(Etapa = etapas, Valor = valores)
    
    # Crear el funnel plot con plotly
    fig <- plot_ly(df, type = "funnel", x = ~Valor, y = ~Etapa, text =  ~paste(round(Valor *100/total_clientes,  1), "%"), 
                   hoverinfo = 'text') 
    
    fig <- fig  %>% layout(title = "Funnel de Clientes", yaxis = list(title = ""),
                           showlegend = FALSE,
                           xaxis = list(fixedrange = TRUE),
                           yaxis = list(fixedrange = TRUE)) %>% config(fig, staticPlot = TRUE, scrollZoom = FALSE, displayModeBar = F)
    
    # Mostrar el funnel plot
    fig
  })
  
  # Visualización funnel de productos que incluye las transformacioens previas realizadas
  output$Plot_funnel_productos <- renderPlotly({
    total_productos <- length(DimArticulo$Codigo)
    
    ventas_2022 <- subset(FactVentas, year(Fecha_factura)==2022, select = c(ArticuloID))
    ventas_6m <- subset(FactVentas, year(Fecha_factura)==2022 & month(Fecha_factura) > 6, select = c(ArticuloID))
    
    # Realizar el conteo de productos distintos
    productos_ventas <- length(unique(FactVentas$ArticuloID))
    productos_ventas2022 <- length(unique(ventas_2022$ArticuloID))
    productos_6m <- length(unique(ventas_6m$ArticuloID))
    
    etapas <- c("Productos dados de alta", "Productos ventas 2021 y 2022", "Productos ventas sólo en 2022", "Productos ventas ultimos 6 meses")
    valores <- c(total_productos, productos_ventas, productos_ventas2022, productos_6m)
    
    # Crear el dataframe
    df <- data.frame(Etapa = etapas, Valor = valores)
    
    # Crear el funnel plot con plotly
    fig <- plot_ly(df, type = "funnel", x = ~Valor, y = ~Etapa, text =  ~paste(round(Valor *100/total_productos,  1), "%"), 
                   hoverinfo = 'text') 
    
    fig <- fig  %>% layout(title = "Funnel de Productos", yaxis = list(title = ""),
                           showlegend = FALSE,
                           xaxis = list(fixedrange = TRUE),
                           yaxis = list(fixedrange = TRUE)) %>% config(fig, staticPlot = TRUE, scrollZoom = FALSE, displayModeBar = F)
    
    # Mostrar el funnel plot
    fig
  })
  
  # Visualización del treemap de actividad que incluye las transformacioens previas realizadas
  output$treemap_actividad <- renderPlotly({
    
    dfcliente <- subset(DimCliente, select=c(ClienteID, ActividadID))
    
    dfventasactividad <- merge(subset(FactVentas, year(Fecha_factura) == 2022, select=c(ClienteID, Importe_linea)), dfcliente, by = "ClienteID", all.x = TRUE)
    
    dfventasactividad$Sector <- ifelse(substr(dfventasactividad$ActividadID, 1, 1) == "1", "1 - Sector primario",
                                       ifelse(substr(dfventasactividad$ActividadID, 1, 1) == "2", "2 - Sector secundario",
                                              ifelse(substr(dfventasactividad$ActividadID, 1, 1) == "3", "3 - Sector terciario",
                                                     "Particulares")))
    
    dfventasactividad$ClienteID <- NULL
    
    
    dfgroup <- as.data.frame(dfventasactividad %>%
                               group_by(Sector, ActividadID) %>%
                               summarise(Importe_ventas = round(sum(Importe_linea), 0) ) )
    
    #Se agrupan actividades con pocas ventas para una mejor visualización
    dfgroup$ActividadID <- ifelse(dfgroup$Importe_ventas < 250000 & dfgroup$Sector == "2 - Sector secundario", "299",
                                  ifelse(dfgroup$Importe_ventas < 25000 & dfgroup$Sector == "3 - Sector terciario", "399", dfgroup$ActividadID))
    
    dfgroup <- as.data.frame(dfgroup %>%
                               group_by(Sector, ActividadID) %>%
                               summarise(Importe_ventas = round(sum(Importe_ventas), 0) ) )
    
    dfsector <- as.data.frame(dfgroup %>%
                                group_by(Sector) %>%
                                summarise(Importe_ventas = round(sum(Importe_ventas), 0) ) )
    
    treemap_data <- list(
      label = c(unique(dfgroup$Sector), dfgroup$ActividadID),
      parent = c("", "", "", "", dfgroup$Sector),
      value = c(dfsector$Importe_ventas, dfgroup$Importe_ventas)
    )
    
    fig <- plot_ly(
      type = "sunburst", insidetextorientation='horizontal',
      labels = treemap_data$label, parents = treemap_data$parent, values = treemap_data$value) %>% 
      layout(title = "Ventas 2022 por Sector y Actividad de cliente")  %>% config(displayModeBar = F)
    
    fig
    
  })
  
  # Visualización del treemap de familais de productos que incluye las transformacioens previas realizadas
  output$treemap_familias <- renderPlotly({
    
    dfarticulo <- merge(subset(DimArticulo, select=c(Codigo, FamiliaID, SubfamiliaID)), DimFamilia, by = "FamiliaID", all.x = TRUE)
    dfarticulo$Familia <- paste(dfarticulo$FamiliaID, dfarticulo$Descripcion, sep = " - ")
    dfarticulo$Descripcion <- NULL
    dfarticulo <- merge(dfarticulo, DimSubfamilia, by = "SubfamiliaID", all.x = TRUE)
    dfarticulo$Subfamilia <- paste(dfarticulo$SubfamiliaID, dfarticulo$Descripcion, sep = " - ")
    dfarticulo$Descripcion <- NULL
    
    dfventasarticulo <- merge(subset(FactVentas, year(Fecha_factura) == 2022, select=c(ArticuloID, Importe_linea)), dfarticulo, by.x = "ArticuloID", by.y = "Codigo", all.x = TRUE)
    
    dfventasarticulo$ArticuloID <- NULL
    dfventasarticulo$SubfamiliaID <- NULL
    dfventasarticulo$FamiliaID <- NULL
    
    
    dfsubfamilia <- as.data.frame(dfventasarticulo %>%
                                    group_by(Familia, Subfamilia) %>%
                                    summarise(Importe_ventas = round(sum(Importe_linea), 0) ) )
    
    dffamilia <- as.data.frame(dfventasarticulo %>%
                                 group_by(Familia) %>%
                                 summarise(Importe_ventas = round(sum(Importe_linea), 0) ) )
    
    treemap_data <- list(
      label = c(unique(dfsubfamilia$Familia), dfsubfamilia$Subfamilia),
      parent = c("", "", "", "", "", "", "", "", "", "", "", "", "", "", dfsubfamilia$Familia),
      value = c(dffamilia$Importe_ventas, dfsubfamilia$Importe_ventas)
    )
    
    
    fig <- plot_ly(
      type = "treemap",
      labels = treemap_data$label, parents = treemap_data$parent, values = treemap_data$value) %>% 
      layout(title = "Ventas 2022 por Familia y Subfamilia de producto")  %>% config(displayModeBar = F)
    
    fig
    
  })
  
  # EXPLORER #
  # Visualización explorador de variables con pivottable
  output$Pivot_explorador <- renderRpivotTable ({
    
    dfventas <- merge(subset(FactVentas, select=c(SucursalID, Isla, ClienteID, Tipo_documento, Fecha_factura, ArticuloID, VendedorID, Importe_linea, Coste_linea, Peso_linea, Margen_bruto)), DimSucursal, by.x = "SucursalID", by.y = "SucursalID", all.x = TRUE)
    dfventas$Sucursal <- paste(dfventas$SucursalID, dfventas$Nombre, sep = " - ")
    
    dfcliente <- merge(subset(DimCliente, select=c(ClienteID, Forma_juridica, Tipo_cliente, ActividadID, Tarifa, Descuento, Metodo_pago, Dias_pago)), DimActividad, by.x = "ActividadID", by.y = "ActividadID", all.x = TRUE)
    dfcliente$Actividad <- paste(dfcliente$ActividadID, dfcliente$Descripcion, sep = " - ")
    
    dfarticulo <- merge(merge(subset(DimArticulo, select=c(Codigo, FamiliaID, SubfamiliaID, Formato, Categoria)), DimFamilia, by.x = "FamiliaID", by.y = "FamiliaID", all.x = TRUE), DimSubfamilia, by.x = "SubfamiliaID", by.y = "SubfamiliaID", all.x = TRUE)
    dfarticulo$Familia <- paste(dfarticulo$FamiliaID, dfarticulo$Descripcion.x, sep = " - ")
    dfarticulo$Subfamilia <- paste(dfarticulo$SubfamiliaID, dfarticulo$Descripcion.y, sep = " - ")
    dfarticulo <- subset(dfarticulo, select=c(Codigo, Familia, Subfamilia, Formato, Categoria))
    
    dftiempo <- subset(DimTiempo, select=c(Fecha, Año, Nombre_mes, Dia_semana, Trimestre, Temporada))
    dfventas <- merge(merge(merge(dfventas, dftiempo, by.x = "Fecha_factura", by.y = "Fecha", all.x = TRUE), dfarticulo, by.x = "ArticuloID", by.y = "Codigo", all.x = TRUE), dfcliente, by="ClienteID", all.x = TRUE)
    
    columnas_a_eliminar <- c("Nombre", "ActividadID", "SucursalID", "Fecha_factura", "Descripcion", "Latitud", "Longitud")
    dfventas <- dfventas[, !names(dfventas) %in% columnas_a_eliminar]
    colnames(dfventas) <- c("Cliente", "Articulo", "Isla", "Tipo_documento", "Vendedor", "Importe", "Coste", "Peso", "Margen", "Sucursal", "Año", "Nombre_mes", "Dia_semana", "Trimestre", "Temporada", "A_Familia" , "A_Subamilia", "A_Formato", "A_Categoria", "C_Forma_juridica", "C_Tipo_cliente", "C_Tarifa", "C_Descuento", "C_Metodo_pago", "C_Dias_pago",  "C_Actividad" )
    
    pvtable <- rpivotTable(dfventas, rows=c("Sucursal","Año"), cols="A_Familia", aggregatorName="Sum", vals="Importe", renderName = "Heatmap", missingValue = 0)
    
  })
  
  # INTERACTIVE MAP #
  # Visualización mapa interactivo
  output$map <- renderLeaflet({
    
    dfmapventas
    max_valor = max(dfmapventas$Importe_ventas)
    min_valor = min(dfmapventas$Importe_ventas)
    min_escala <- 1
    max_escala <- 4
    
    mapa <- leaflet() %>% setView(lng = -16, lat = 28.6, zoom = 8)
    
    mapa <- mapa %>%
      addCircleMarkers(
        data = dfmapventas,
        lng = ~Longitud,
        lat = ~Latitud,
        radius = ~((Importe_ventas - min_valor) / (max_valor - min_valor)) * (max_escala - min_escala) + min_escala, #~ifelse(Importe_ventas/100000 > 100, 45, Importe_ventas/100000), # Tamaño del radio ajustado según el volumen de ventas
        color = "red",
        stroke = FALSE,
        fillOpacity = 0.5,
        label = ~paste0("Cliente: ", ClienteID, " - ", Importe_ventas," €")
      ) %>% fitBounds(lng1 = min(dfmapventas$Longitud), lat1 = min(dfmapventas$Latitud),
                      lng2 = max(dfmapventas$Longitud), lat2 = max(dfmapventas$Latitud))
    
    mapa <- mapa %>%
      addCircleMarkers(
        data = DimSucursal,
        lng = ~Longitud,
        lat = ~Latitud,
        radius = 0.5, 
        color = "blue",
        stroke = FALSE,
        fillOpacity = 0.9,
        label = ~paste0("Sucursal: ", SucursalID)
      )
    
    mapa <- mapa %>% addProviderTiles("OpenStreetMap")
    
    mapa
    
  })
  
  # Función observe para actualizar el mapa cuando se realiza zoom
  observe({
    dfmapventas
    
    # Escalado
    max_valor = max(dfmapventas$Importe_ventas)
    min_valor = min(dfmapventas$Importe_ventas)
    min_escala <- 1
    max_escala <- 4
    
    zoom <- input$map_zoom
    if (!is.null(zoom)) {
      leafletProxy("map") %>%
        clearMarkers() %>%
        addCircleMarkers(
          data = dfmapventas,
          lng = ~Longitud,
          lat = ~Latitud,
          radius = ~(((Importe_ventas - min_valor) / (max_valor - min_valor)) * (max_escala - min_escala) + min_escala) * zoom, #~ifelse((Importe_ventas/100000 * zoom) > 100, 45, Importe_ventas/100000 * zoom), # Ajustar el tamaño del radio según el nivel de zoom
          color = "red",
          stroke = FALSE,
          fillOpacity = 0.5,
          label = ~paste0("Cliente: ", ClienteID, " - ", Importe_ventas," €")
        ) %>%
        addCircleMarkers(
          data = DimSucursal,
          lng = ~Longitud,
          lat = ~Latitud,
          radius = 0.5 * zoom, 
          color = "blue",
          stroke = FALSE,
          fillOpacity = 0.9,
          label = ~paste0("Sucursal: ", SucursalID)
        )
    }
  })
  
  # RRHH #
  # Visualizaciones de los indicadores KPIs de RRHH: Edad media, salario y antigúedad
  output$infoboxedadmedia <- renderInfoBox({
    
    edad_media <- round(mean(DimPersonal$Edad), 1)
    
  shinydashboard::infoBox(
      title = tags$p(style = "font-size: 16px;", paste0("Edad media de la plantilla")),
      value = tags$p(paste0(edad_media," años")),
      fill = F, color = "light-blue", icon = shiny::icon("people-group")
    )
  })
  
  output$infoboxsalario <- renderInfoBox({
    
    salario <- round(median(DimPersonal$Salario), 1)
    
    shinydashboard::infoBox(
      title = tags$p(style = "font-size: 16px;", paste0("Salario anual mediana")),
      value = tags$p(paste0(salario,"\U20AC")),
      fill = F, color = "light-blue", icon = shiny::icon("sack-dollar")
    )
  })
  
  output$infoboxantiguedad <- renderInfoBox({
    
    antiguedad <- round(median(DimPersonal$Antiguedad), 1)
    
    shinydashboard::infoBox(
      title = tags$p(style = "font-size: 16px;", paste0("Antiguedad media de los empleados")),
      value = tags$p(paste0(antiguedad," años")),
      fill = F, color = "light-blue", icon = shiny::icon("business-time")
    )
  })
  
  # Visualización gráfico de donut para la representación de género
  output$donutchart <- renderPlotly({
    donut_data <- table(DimPersonal$Genero)
    labels <- names(donut_data)
    values <- prop.table(donut_data) * 100
    
    donut_chart <- plot_ly(
      labels = labels,
      values = values,
      type = "pie",
      hole = 0.6,
      textinfo = "label+percent",
      hoverinfo = "text",
      textposition = "inside"
    )
    
    donut_chart <- donut_chart %>% layout(
      title = "Porcentaje de hombres y mujeres",
      showlegend = FALSE)  %>% config(displayModeBar = F)
    
    donut_chart
    
  })
  
  # Visualización gráfico de dispersión Antigüedad vs Salario con 4 variables
  output$Plot_antiguedad_salario <- renderPlotly({
    shapes <- ifelse(DimPersonal$Genero == "F", "square", "triangle")
    colors <- factor(DimPersonal$Nivel_estudios)
    
    # Crear el gráfico de dispersión
    fig <- plot_ly(DimPersonal, x = ~Antiguedad, y = ~Salario, text = ~EmpleadoID, mode = "markers", type = "scatter", symbol = ~shapes, color = ~colors, size = 6) %>% 
      layout(
        title = "Gráfico de Dispersión: Antigüedad VS. Salario anual",
        xaxis = list(title = "Antigüedad", zeroline = F),
        yaxis = list(title = "Salario"),
        margin = list(r = 20),
        hovermode = "closest",
        showlegend = TRUE
      ) %>% config(displayModeBar = F)
    
    # Mostrar el gráfico
    fig
    
  })
  
  
  # Código no utilizado gráfico de líneas animado para representar los beneficios de los últimos años
  # output$Plot_animatemargen <- renderPlotly({
  #   
  #   dfmargen <- merge(subset(FactVentas, select = c(Fecha_factura, Margen_bruto)), DimTiempo, by.x = "Fecha_factura", by.y = "Fecha", all.x = TRUE)
  #   
  #   dfmargen <- as.data.frame(dfmargen %>%
  #                               group_by(Mes, Año) %>%
  #                               summarise(Beneficios = round(sum(Margen_bruto), 0) ) )
  #   
  #   dfmargen <- dfmargen[order(dfmargen$Año, dfmargen$Mes), ]
  #   dfmargen$Fecha <- as.Date(paste(dfmargen$Año, dfmargen$Mes, "01", sep="-"))
  #   dfmargen$Año <- NULL
  #   dfmargen$Mes <- NULL
  #   
  #   
  #   fig <- plot_ly(
  #     x = dfmargen$Fecha,
  #     y = dfmargen$Beneficios,
  #     type = 'scatter',
  #     mode = 'lines+markers',
  #     text = paste0(dfmargen$Beneficios, " €"), hoverinfo="text",
  #   )
  #   fig <- fig %>% layout (title = "Beneficios por Mes",
  #                          xaxis = list(
  #                            title = "Fecha",
  #                            zeroline = F
  #                          ),
  #                          yaxis = list(
  #                            title = "",
  #                            zeroline = F
  #                          ),
  #                          margin = list(l = 15)
  #   ) %>% config(fig, displayModeBar = F)
  #   
  #   fig
  # })
  
}

# Run the application 
shinyApp(ui = ui, server = server)
