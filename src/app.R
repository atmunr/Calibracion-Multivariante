library(stringr)
library(shiny)
library(shinythemes)
source("calibpred.R")
source("preprocesar.R")

 # datos ingresados al programa
INPUT <- reactiveValues()
INPUT$calib.x  <- NULL # espectros de calibrado
INPUT$calib.y  <- NULL # concentraciones de calibrado
INPUT$prueba.x <- NULL # espectros de prueba
INPUT$prueba.y <- NULL # concentraciones de prueba

 # datos ingresados, luego de ser preprocesados
PREPRO <- reactiveValues()
PREPRO$calib.x         <- NULL # espectros de calibrado preprocesados
PREPRO$calib.y         <- NULL # concentraciones de calibrado preprocesadas
PREPRO$prueba.x        <- NULL # espectros de prueba preprocesados
 # si se centran los datos, el promedio de los espectros de calibrado
PREPRO$calib.x.especProm <- NULL
 # si se centran los datos, el promedio de las concentraciones de calibrado
PREPRO$calib.y.concentProm <- NULL

 # resultados de la calibrado multivariada
OUTPUT <- reactiveValues()
OUTPUT$coefRegr      <- NULL # coeficientes de regresión
 # error ESTADístico PRESS para cada número de variables latentes
OUTPUT$press.nvl     <- NULL
 # ESTADística F producida con los valores PRESS para cada número de variables latentes
OUTPUT$fstat.nvl     <- NULL
 # probabilidad de obtener cada ESTADística F
OUTPUT$probFstat.nvl <- NULL
 # las concentraciones que predice la calibrado multivariada
OUTPUT$concentPred   <- NULL
 # número óptimo de variables latentes, obtenido por validación cruzada
OUTPUT$nvl.optimo    <- NULL

 # datos estadísticos sobre la predicción
ESTAD <- reactiveValues()
 # diferencia entre valor predicho y nominal para cada muestra
ESTAD$errores <- NULL
ESTAD$RMSEP   <- NULL
ESTAD$REP     <- NULL

# defición de la interfaz gráfica
ui <- fluidPage( #theme = shinytheme('darkly'),

	headerPanel( 'First-order multivariate calibration' ),
	tabsetPanel(

		# ingreso de datos, elección de sensores y eleminación de muestras
		tabPanel( 'Data input',
			sidebarPanel(
				# ingresar de archivos de entrada
				fileInput( 'calib.x'  , 'Calibration spectra' ),
            	fileInput( 'calib.y'  , 'Calibration analyte concentrations' ),
            	fileInput( 'prueba.x' , 'Test spectra' ),
				fileInput( 'prueba.y' , 'Test analyte concentrations' ),
				# elegir de sensores
				textInput( 'INPUT.elegirSensores', 'Select sensors' ),
				# quitar muestras
				textInput( 'INPUT.quitarMuestras.calib', 'Remove calibration samples' ),
				textInput( 'INPUT.quitarMuestras.prueba', 'Remove test samples' ),
				# aplicar cambios
				actionButton('INPUT.aplicar', 'Apply changes' )
			),
			mainPanel(tabsetPanel( # mostrar datos en forma de tabla
				tabPanel( 'Plots', # mostrar datos como una gráfica
				selectInput( 'INPUT.mostrar.grafica', 'Display:', c(
				'Calibration spectra' =  'calib.x',
				'Calibration analyte concentrations' =  'calib.y',
				'Test spectra' = 'prueba.x',
				'Test analyte concentrations' = 'prueba.y'
				)), plotOutput( 'INPUT.mostrar.grafica.figura' )
				),
				tabPanel( 'Raw data',
				selectInput( 'INPUT.mostrar.crudo', 'Display:', c(
				'Calibration spectra' =  'calib.x',
				'Calibration analyte concentrations' =  'calib.y',
				'Test spectra' = 'prueba.x',
				'Test analyte concentrations' = 'prueba.y'
				)),
				downloadButton('INPUT.descargar', 'Download'),
				fluidRow(column(dataTableOutput(outputId = 'INPUT.mostrar.crudo.figura'), width = 10))
				)

			))
  		),

		# sección de preprocesamiento de datos
		tabPanel( 'Digital pre-processing',
			sidebarPanel(
				# elegir de algoritmos de preprocesamiento
				checkboxInput( 'PREPRO.centrar', 'Mean centering' ),
				checkboxInput( 'PREPRO.SavitzkyGolay', 'Smoothing/derivatives (Savitzky-Golay)' ),
				numericInput( 'PREPRO.SavitzkyGolay.ord', 'Derivative order',
					min = 0, value = 0 ),
				numericInput( 'PREPRO.SavitzkyGolay.grad', 'Polynomial degree',
					min = 1, value = 1 ),
				numericInput( 'PREPRO.SavitzkyGolay.vlen', 'Window size',
					min = 3, value = 3, step = 2 ),
				checkboxInput( 'PREPRO.MSC', 'Multiplicative Scattering Correction' ),
				# aplicar cambios
				actionButton( 'PREPRO.aplicar', 'Apply changes' )
			),
			mainPanel(tabsetPanel(
				# mostrar datos procesados en forma de gráfica
				tabPanel( 'Plots',
				selectInput( 'PREPRO.mostrar.grafica', 'Display:', c(
				'Calibration spectra' =  'calib.x',
				'Calibration analyte concentrations' =  'calib.y',
				'Test spectra' = 'prueba.x'
				)), plotOutput( 'PREPRO.mostrar.grafica.figura' )
				),
				# mostrar datos procesados en forma de tabla
				tabPanel( 'Raw data',
				selectInput( 'PREPRO.mostrar.crudo', 'Display:', c(
				'Calibration spectra' =  'calib.x',
				'Calibration analyte concentrations' =  'calib.y',
				'Test spectra' = 'prueba.x'
				)),
				downloadButton('PREPRO.descargar', 'Download'),
				fluidRow(column(dataTableOutput(outputId = 'PREPRO.mostrar.crudo.figura'), width = 10))
				)
			))
  		),

		# sección de construcción y validación del modelo y predicción
		tabPanel( 'Validation and predictions',
			sidebarPanel(
				# validación del modelo
				tags$b( 'Cross-validation'),
				# elección del método de validación
				selectInput( 'OUTPUT.valid.alg', 'Validation techniques:',
					c('Leave-one-out' = 'LOO'
				)),
				# elección del número máximo de variables latentes para la
				# validación
				numericInput( 'OUTPUT.nvl.max', 'Maximum number of latent variables',
                	value = 1, min = 1 ),
				# validación del modelo
				actionButton( 'OUTPUT.validarModelo', 'CV' ),

				tags$br(), tags$b('Optimum number of latent variables: '),
				textOutput( 'OUTPUT.mostrar.nvl.optimo', inline = TRUE ),

				 # elección del algoritmo
            	selectInput( 'OUTPUT.pred.alg', 'Prediction models:',
                	c('PLS-1' = 'PLS1'#,
                	  #'PCR'   = 'PCR'
            	)),
				# elección del número de variables latentes
            	numericInput( 'OUTPUT.nvl', 'Latent variables',
                	value = 1, min = 1 ),
				# construcción del modelo
            	actionButton( 'OUTPUT.construirModelo', 'Predict' )
			),
			mainPanel(tabsetPanel(
				# mostrar resultados de predicción en forma de gráfica
				tabPanel( 'Plots',
				selectInput( 'OUTPUT.mostrar.grafica', 'Display:', c(
				'Sum of square errors vs. number of latent variables' =  'press.nvl',
				'F statistic vs. number of latent variables' = 'fstat.nvl',
				'Associated probability vs. number of latent variables' = 'probFstat.nvl',
				'Regression coefficients' =  'coefRegr',
				'Predicted concentrations' = 'concentPred',
				'Test analyte concentrations' = 'prueba.y'
				)), plotOutput( 'OUTPUT.mostrar.grafica.figura' )
				),
				# mostrar resultados de predicción en forma de tabla
			  	tabPanel( 'Raw data',
				selectInput( 'OUTPUT.mostrar.crudo', 'Display:', c(
			   	'Sum of square errors vs. number of latent variables' =  'press.nvl',
			  	'F statistic vs. number of latent variables' = 'fstat.nvl',
			   	'Associated probability vs. number of latent variables' = 'probFstat.nvl',
				'Regression coefficients' = 'coefRegr',
			   	'Predicted concentrations' = 'concentPred',
			   	'Test analyte concentrations' = 'prueba.y'
				)),
				downloadButton('OUTPUT.descargar', 'Download'),
				fluidRow(column(dataTableOutput(outputId = 'OUTPUT.mostrar.crudo.figura'), width = 10))
			   	)
			))
  		),
		# estadísticas sobre la calidad de la predicción
		tabPanel( 'Statistics',
			sidebarPanel(
				tags$b('RMSEP: '), textOutput( 'ESTAD.mostrar.RMSEP', inline=TRUE ), tags$br(),
				tags$hr(),
				tags$b('REP: '  ), textOutput( 'ESTAD.mostrar.REP'  , inline=TRUE ), tags$br(),
				tags$hr()
			),
			mainPanel(tabsetPanel(
				tabPanel( 'Plots',
 				selectInput( 'ESTAD.mostrar.grafica', 'Display:', c(
 				'Predicted vs. nominal ' = 'concentPred.vs.prueba.y',
 				'Concentration errors (nominal - predicted)' = 'error.vs.concentPred'
				)), plotOutput( 'ESTAD.mostrar.grafica' )
				),
				tabPanel( 'Raw data',
				selectInput( 'ESTAD.mostrar.crudo', 'Display:', c(
 				'Concentration errors: (nominal - predicted)' = 'concentPred.vs.prueba.y'
				)),
				downloadButton('ESTAD.descargar', 'Download'),
				fluidRow(column(dataTableOutput(outputId = 'ESTAD.mostrar.crudo.figura'), width = 10))
				)
			))
  		)
	)
)

# defición del código de servidor
server <- function( input, output ) {

	# definición de datos ingresados a la herramienta:
	observeEvent( input$INPUT.aplicar, {

		# nulificar valores que dependen de INPUT
		PREPRO$calib.x             <<- NULL
		PREPRO$calib.y             <<- NULL
		PREPRO$prueba.x            <<- NULL
		PREPRO$calib.x.especProm   <<- NULL
		PREPRO$calib.y.concentProm <<- NULL
		OUTPUT$coefRegr            <<- NULL
		OUTPUT$press.nvl           <<- NULL
		OUTPUT$fstat.nvl           <<- NULL
		OUTPUT$probFstat.nvl       <<- NULL
		OUTPUT$concentPred         <<- NULL
		OUTPUT$nvl.optimo          <<- NULL
		ESTAD$errores              <<- NULL

		# cargar archivos
		if (!is.null( input$calib.x )) {
			   INPUT$calib.x  <<- as.matrix(read.table((input$calib.x)$datapath))
		} else INPUT$calib.x  <<- NULL

		if (!is.null( input$calib.y )) {
			   INPUT$calib.y  <<- as.matrix(read.table((input$calib.y)$datapath))
		} else INPUT$calib.y  <<- NULL

		if (!is.null( input$prueba.x )) {
			   INPUT$prueba.x <<- as.matrix(read.table((input$prueba.x)$datapath))
		} else INPUT$prueba.x <<- NULL

		if (!is.null( input$prueba.y )) {
			   INPUT$prueba.y <<- as.matrix(read.table((input$prueba.y)$datapath))
		} else INPUT$prueba.y <<- NULL

		# toma un string con intervalos de números y, si son válidos, los
		# convierte a un vector de pares de números. Si no, devuelve NULL.
		# verifica que los intervalos representan un subconjunto de valores
		# del rango [1,N]
		procesarIntervalos <- function( intervalos, nmax ) {
			# verificar que solo hayan números o espacios
			if (grepl("^[0-9 ]+$", intervalos) == FALSE) return(NULL)
			# quitar espacios al principio y fin y unir espacios consecutivos en uno
			intervalos <- gsub("\\s+", " ", str_trim(intervalos))
			# obtener un vector de strings
			intervalos <- strsplit(intervalos, split = " ")
			intervalos <- intervalos[[1]]
			# verificar que haya un número par de valores
			if (length(intervalos) %% 2 != 0) return(NULL)
			# obtener un vector de números
			intervalos <- strtoi(intervalos)
			# verificar que sean subintervalos del rango [1,N]
			if (min(intervalos) < 1 || max(intervalos) > nmax) return(NULL)
			# obtener un vector de pares de valores
			intervalos <- split(intervalos, ceiling(seq_along(intervalos)/2))
			return(intervalos)
		}

		# quitar sensores
		if (input$INPUT.elegirSensores != "") {
			if (!is.null(INPUT$calib.x)) {
				sensores <- procesarIntervalos(input$INPUT.elegirSensores, nrow(INPUT$calib.x))
				if (is.null(sensores)) INPUT$calib.x <<- NULL
				else INPUT$calib.x  <<- PrePro.FiltrarSensores(INPUT$calib.x, sensores)
			}
			if (!is.null(INPUT$prueba.x)) {
				sensores <- procesarIntervalos(input$INPUT.elegirSensores, nrow(INPUT$prueba.x))
				if (is.null(sensores)) INPUT$prueba.x <<- NULL
				else INPUT$prueba.x  <<- PrePro.FiltrarSensores(INPUT$prueba.x, sensores)
			}
		}

		# quitar muestras de calibrado
		if (input$INPUT.quitarMuestras.calib != "") {
			if (!is.null(INPUT$calib.x)) {
				muestras <- procesarIntervalos(input$INPUT.quitarMuestras.calib, ncol(INPUT$calib.x))
				if (is.null(muestras)) INPUT$calib.x <<- NULL
				else INPUT$calib.x  <<- PrePro.QuitarMuestras.Espectro(INPUT$calib.x, muestras)
			}
			if (!is.null(INPUT$calib.y)) {
				muestras <- procesarIntervalos(input$INPUT.quitarMuestras.calib, nrow(INPUT$calib.y))
				if (is.null(muestras)) INPUT$calib.y <<- NULL
				else INPUT$calib.y  <<- PrePro.QuitarMuestras.Concent(INPUT$calib.y, muestras)
			}
		}
		# quitar muestras de prueba
		if (input$INPUT.quitarMuestras.prueba != "") {
			if (!is.null(INPUT$prueba.x)) {
				muestras <- procesarIntervalos(input$INPUT.quitarMuestras.prueba, ncol(INPUT$prueba.x))
				if (is.null(muestras)) INPUT$prueba.x <<- NULL
				else INPUT$prueba.x  <<- PrePro.QuitarMuestras.Espectro(INPUT$prueba.x, muestras)
			}
			if (!is.null(INPUT$prueba.y)) {
				muestras <- procesarIntervalos(input$INPUT.quitarMuestras.prueba, nrow(INPUT$prueba.y))
				if (is.null(muestras)) INPUT$prueba.y <<- NULL
				else INPUT$prueba.y  <<- PrePro.QuitarMuestras.Concent(INPUT$prueba.y, muestras)
			}
		}

	})

	# visualizaciones de los datos ingresados
	observe({
		# visualizacion en tabla:
		# con la opción elegida en el widget INPUT.mostrar.crudo
		# se elige el valor correspondiente para pasar a renderTable()
		# y se lo asigna a INPUT.mostrar.crudo.figura
		mostrar.crudo.val <- as.data.frame(switch(input$INPUT.mostrar.crudo,
			 'calib.x' = INPUT$calib.x ,
			 'calib.y' = INPUT$calib.y ,
			'prueba.x' = INPUT$prueba.x,
			'prueba.y' = INPUT$prueba.y
		))

		output$INPUT.descargar <- downloadHandler(
			filename = function(){'download.txt'},
			content = function(fname){
				colnames(mostrar.crudo.val) <- NULL
				write.table(reactive(as.matrix(mostrar.crudo.val))(), fname, sep=' ', row.names=FALSE, col.names=FALSE)
			}
		)
		output$INPUT.mostrar.crudo.figura <- renderDataTable(
			{reactive(mostrar.crudo.val)()},
			options = list(scrollX = TRUE)
		)

		# visualizacion en gráfica:
		# con la opción elegida en el widget INPUT.mostrar.grafica
		# se elige el valor correspondiente y se lo asigna a
		# INPUT.mostrar.grafica.val, para luego pasarlo a renderPlot()
		mostrar.grafica.val <- switch(input$INPUT.mostrar.grafica,
			 'calib.x' = INPUT$calib.x ,
			 'calib.y' = INPUT$calib.y ,
			'prueba.x' = INPUT$prueba.x,
 			'prueba.y' = INPUT$prueba.y
		)
		# caso especial: si no existe el valor que corresponde a la opción
		# elegida (el valor es igual a NULL), asigna directamente a
		# INPUT.mostrar.grafica.figura el valor NULL, para evitar llamar
		# a renderPlot(NULL) (no le gusta)
		if (is.null(mostrar.grafica.val)) {
			      output$INPUT.mostrar.grafica.figura <- NULL
		# llama a renderPlot(INPUT.mostrar.grafica.val) y se lo asigna a
		# INPUT.mostrar.grafica.figura
		} else {  output$INPUT.mostrar.grafica.figura <- renderPlot({
			switch(input$INPUT.mostrar.grafica,
				# llama a matplot() directamente, dado que los espectros se
				# almacenan como columnas en una matriz
				'calib.x' = , 'prueba.x' = {
					matplot( 1 : nrow(mostrar.grafica.val), mostrar.grafica.val,
   						xlab = 'Sensor', ylab = 'Intensity',
   						lwd = 1.5, type = 'l' ) },
				# como las concentraciones se almacenan en una matriz (a pesar
				# de ser una sola columna) se llama a la función plot sobre
				# la primer columna
				'calib.y' = , 'prueba.y' = {
					plot( 1 : nrow(mostrar.grafica.val), mostrar.grafica.val[,1],
   						xlab = 'Sample number', ylab = 'Concentration',
   						bg = 'black', pch = 20, cex = 1.3 )
					lines(mostrar.grafica.val) }
			)
		})}
	})

	# preprocesamiento de los datos de entrada
	observeEvent( input$PREPRO.aplicar, {

		# nulificar valores que dependen de PREPRO
		OUTPUT$coefRegr            <<- NULL
		OUTPUT$press.nvl           <<- NULL
		OUTPUT$fstat.nvl           <<- NULL
		OUTPUT$probFstat.nvl       <<- NULL
		OUTPUT$concentPred         <<- NULL
		OUTPUT$nvl.optimo          <<- NULL
		ESTAD$errores              <<- NULL

		# existen los datos preprocesados si se cargaron los datos necesarios
		# por defecto, calib.x preprocesado es calib.x
		if (!is.null(INPUT$calib.x)) {
			   PREPRO$calib.x  <<- INPUT$calib.x
		} else PREPRO$calib.x  <<- NULL
		# por defecto, calib.y preprocesada es calib.y
		if (!is.null(INPUT$calib.y)) {
			   PREPRO$calib.y  <<- INPUT$calib.y
		} else PREPRO$calib.y  <<- NULL
		# por defecto, prueba.x preprocesado es prueba.x
		if (!is.null(INPUT$prueba.x)) {
			   PREPRO$prueba.x <<- INPUT$prueba.x
		} else PREPRO$prueba.x <<- NULL

		if (input$PREPRO.MSC == TRUE) {
			if (!is.null(PREPRO$calib.x) && !is.null(PREPRO$prueba.x)) {
				outMSC <- PrePro.MSC(PREPRO$calib.x, PREPRO$prueba.x)
				PREPRO$calib.x  <<- outMSC[[1]]
				PREPRO$prueba.x <<- outMSC[[2]]
			}
		}

		if (input$PREPRO.SavitzkyGolay == TRUE) {
			if (!is.null(PREPRO$calib.x)) {
				PREPRO$calib.x <<- PrePro.SavitzkyGolay( PREPRO$calib.x,
					input$PREPRO.SavitzkyGolay.ord,
					input$PREPRO.SavitzkyGolay.grad,
					input$PREPRO.SavitzkyGolay.vlen)
			}
			if (!is.null(PREPRO$prueba.x)) {
				PREPRO$prueba.x <<- PrePro.SavitzkyGolay( PREPRO$prueba.x,
					input$PREPRO.SavitzkyGolay.ord,
					input$PREPRO.SavitzkyGolay.grad,
					input$PREPRO.SavitzkyGolay.vlen)
			}
		}

		# centrado de los datos
		# (sólo se puede hacer algún centrado si existen los espectros de calibrado)
		if (input$PREPRO.centrar == TRUE && !is.null(PREPRO$calib.x)) {
			# calcula el promedio de los espectros de calibrado y lo guarda
			# como una matrix columna
			PREPRO$calib.x.especProm <<- matrix(nrow = nrow(PREPRO$calib.x))
			for (i in 1 : nrow(PREPRO$calib.x)) {
				PREPRO$calib.x.especProm[i] <<- mean(PREPRO$calib.x[i,])
			}

			# centrado de los espectros de calibrado:
			# restarle el espectro promedio a todos los espectros de calibrado
			for (i in 1 : ncol(PREPRO$calib.x)) {
				PREPRO$calib.x[,i] <<- PREPRO$calib.x[,i] - PREPRO$calib.x.especProm
			}

			# centrado de las concentraciones de calibrado:
			# calcular el promedio de todas las concentraciones de calibrado
			# y restárselo a todas las concentraciones de calibrado
			if (!is.null(PREPRO$calib.y)) {
				PREPRO$calib.y.concentProm <<- mean(PREPRO$calib.y)
				PREPRO$calib.y <<- PREPRO$calib.y - PREPRO$calib.y.concentProm
			}

			# centrado de los espectros de prueba:
			# restarle el espectro promedio a todos los espectros de prueba
			if (!is.null(PREPRO$prueba.x)) {
				for (i in 1 : ncol(PREPRO$prueba.x)) {
					PREPRO$prueba.x[,i] <<- PREPRO$prueba.x[,i] - PREPRO$calib.x.especProm
				}
			}
		}

	})

	# visualizaciones de los datos preprocesados
	observe({
		# visualizacion en tabla:
		# con la opción elegida en el widget PREPRO.mostrar.crudo
		# se elige el valor correspondiente para pasar a renderTable()
		# y se lo asigna a PREPRO.mostrar.crudo.figura
		mostrar.crudo.val <- as.data.frame(switch(input$PREPRO.mostrar.crudo,
			 'calib.x' = PREPRO$calib.x ,
			 'calib.y' = PREPRO$calib.y ,
			'prueba.x' = PREPRO$prueba.x
		))

		output$PREPRO.descargar <- downloadHandler(
			filename = function(){'download.txt'},
			content = function(fname){
				colnames(mostrar.crudo.val) <- NULL
				write.table(reactive(as.matrix(mostrar.crudo.val))(), fname, sep=' ', row.names=FALSE, col.names=FALSE)
			}
		)
		output$PREPRO.mostrar.crudo.figura <- renderDataTable(
			{reactive(mostrar.crudo.val)()},
			options = list(scrollX = TRUE)
		)
		# visualizacion en gráfica:
		# con la opción elegida en el widget PREPRO.mostrar.grafica
		# se elige el valor correspondiente y se lo asigna a
		# PREPRO.mostrar.grafica.val, para luego pasarlo a renderPlot()
		mostrar.grafica.val <- switch(input$PREPRO.mostrar.grafica,
			 'calib.x' = PREPRO$calib.x ,
			 'calib.y' = PREPRO$calib.y ,
			'prueba.x' = PREPRO$prueba.x
		)
		# caso especial: si no existe el valor que corresponde a la opción
		# elegida (el valor es igual a NULL), asigna directamente a
		# PREPRO.mostrar.grafica.figura el valor NULL, para evitar llamar
		# a renderPlot(NULL) (no le gusta)
		if (is.null(mostrar.grafica.val)) {
			      output$PREPRO.mostrar.grafica.figura <- NULL
		} else {  output$PREPRO.mostrar.grafica.figura <- renderPlot({
			switch(input$PREPRO.mostrar.grafica,
				# llama a matplot() directamente, dado que los espectros se
				# almacenan como columnas en una matriz
				'calib.x' = , 'prueba.x' = {
					matplot( 1 : nrow(mostrar.grafica.val), mostrar.grafica.val,
   						xlab = 'Sensor', ylab = 'Intensity',
   						lwd = 1.5, type = 'l' ) },
				# como las concentraciones se almacenan en una matriz (a pesar
				# de ser una sola columna) se llama a la función plot sobre
				# la primer columna
				'calib.y' = {
					plot( 1 : nrow(mostrar.grafica.val), mostrar.grafica.val[,1],
   						xlab = 'Sample number', ylab = 'Concentration',
   						bg = 'black', pch = 20, cex = 1.3 )
					lines(mostrar.grafica.val) }
			)
		})}
	})

	# construcción del modelo con los datos de preprocesados y
	# predicción de las concentraciones
	observeEvent( input$OUTPUT.construirModelo, {
		# nulificar valores que dependen de OUTPUT
		ESTAD$errores <<- NULL

		if (input$OUTPUT.pred.alg == 'PLS1') {
			if (!is.null(PREPRO$calib.x) && !is.null(PREPRO$calib.y)) {
			# obtiene los coeficientes como una matriz columna
			OUTPUT$coefRegr <<- CalcularCoefRegr.PLS1(
				PREPRO$calib.x, PREPRO$calib.y, input$OUTPUT.nvl)
			# obtiene las concentraciones de predicción
			if (!is.null(PREPRO$prueba.x)) {
				# multiplica cada espectro de prueba por los coeficientes para
				# obtener las concentraciones
				OUTPUT$concentPred <<- t(PREPRO$prueba.x) %*% OUTPUT$coefRegr
			}
		}

		if (input$OUTPUT.pred.alg == 'PCR') {
			if (!is.null(PREPRO$calib.x) && !is.null(PREPRO$caliby.x)
			 && !is.null(PREPRO$prueba.x)) {
				 OUTPUT$concentPred <<- PredecirConcent.PCR( PREPRO$calib.x,
				 	PREPRO$calib.y, PREPRO$test.x, input$OUTPUT.nvl)
			 }
		}

		# descentralizar
		if (input$PREPRO.centrar == TRUE && !is.null(OUTPUT$concentPred)) {
			OUTPUT$concentPred <<- OUTPUT$concentPred + PREPRO$calib.y.concentProm
		}

	}})

	# validación del modelo:
	# sólo si están definidos calib.x y calib.y
	observeEvent( input$OUTPUT.validarModelo, { if
	(!is.null(PREPRO$calib.x) && !is.null(PREPRO$calib.y)) {
		# si se centraron los datos, se tienen que decentralizar antes de
		# realizar la validacíon del modelo
		calib.x <- PREPRO$calib.x
		calib.y <- PREPRO$calib.y
		if (input$PREPRO.centrar == TRUE) {
			# decentraliza calib.x
 			for ( i in 1 : ncol(PREPRO$calib.x) ) {
 				calib.x[,i] <- PREPRO$calib.x[,i] + PREPRO$calib.x.especProm
 			}
			# decentraliza calib.y
			calib.y <- PREPRO$calib.y + PREPRO$calib.y.concentProm
 		}
		# calcula los errores PRESS por número de variables latentes
		OUTPUT$press.nvl <<- as.matrix(ValidarModelo.LOO.PLS1(
			calib.x, calib.y, input$OUTPUT.nvl.max,
			centrar = input$PREPRO.centrar))
		# calcula las ESTADísticas F producidas con los valores PRESS
		OUTPUT$fstat.nvl <<- OUTPUT$press.nvl / min(OUTPUT$press.nvl)
		for (i in match(1,OUTPUT$fstat.nvl) : length(OUTPUT$fstat.nvl)) {
			if(OUTPUT$fstat.nvl[i] != 1) OUTPUT$fstat.nvl[i] <<- 0
		}

		# calcula las probabilidades de obtener cada ESTADística F
		OUTPUT$probFstat.nvl <<- as.matrix(CalcularProbF(
			OUTPUT$fstat.nvl, ncol(calib.x), ncol(calib.x)))
		# calcula el número óptimo de variables latentes a usar
		for (i in 1 : length(OUTPUT$probFstat.nvl)) {
			if (OUTPUT$probFstat.nvl[i] < 0.75) {
				OUTPUT$nvl.optimo <<-i
				break
			}
		}
		output$OUTPUT.mostrar.nvl.optimo <- renderText(OUTPUT$nvl.optimo)

	}})

	# visualizaciones de los datos obtenidos por la validación del modelo
	observe({
		# visualizacion en tabla:
		# con la opción elegida en el widget OUTPUT.mostrar.crudo
		# se elige el valor correspondiente para pasar a renderTable()
		# y se lo asigna a OUTPUT.mostrar.crudo.figura
		mostrar.crudo.val <- as.data.frame(switch(input$OUTPUT.mostrar.crudo,
			'coefRegr' = OUTPUT$coefRegr,
			'press.nvl' = OUTPUT$press.nvl,
			'fstat.nvl' = OUTPUT$fstat.nvl,
			'probFstat.nvl' = OUTPUT$probFstat.nvl,
			'concentPred' = OUTPUT$concentPred,
			'prueba.y' = INPUT$prueba.y
		))

		output$OUTPUT.descargar <- downloadHandler(
			filename = function(){'download.txt'},
			content = function(fname){
				colnames(mostrar.crudo.val) <- NULL
				write.table(reactive(as.matrix(mostrar.crudo.val))(), fname, sep=' ', row.names=FALSE, col.names=FALSE)
			}
		)
		output$OUTPUT.mostrar.crudo.figura <- renderDataTable(
			{reactive(mostrar.crudo.val)()},
			options = list(scrollX = TRUE)
		)
		# visualizacion en gráfica:
		# con la opción elegida en el widget OUTPUT.mostrar.grafica
		# se elige el valor correspondiente y se lo asigna a
		# OUTPUT.mostrar.grafica.val, para luego pasarlo a renderPlot()
		mostrar.grafica.val <- switch(input$OUTPUT.mostrar.grafica,
			'coefRegr' = OUTPUT$coefRegr,
			'press.nvl' = OUTPUT$press.nvl,
			'fstat.nvl' = OUTPUT$fstat.nvl,
			'probFstat.nvl' = OUTPUT$probFstat.nvl,
			'concentPred' = OUTPUT$concentPred,
			'prueba.y' = INPUT$prueba.y
		)
		# caso especial: si no existe el valor que corresponde a la opción
		# elegida (el valor es igual a NULL), asigna directamente a
		# OUTPUT.mostrar.grafica.figura el valor NULL, para evitar llamar
		# a renderPlot(NULL) (no le gusta)
		if (is.null(mostrar.grafica.val)) {
			      output$OUTPUT.mostrar.grafica.figura <- NULL
		} else {  output$OUTPUT.mostrar.grafica.figura <- renderPlot({
			switch(input$OUTPUT.mostrar.grafica,
				# como todos estos valores se almacenan en matrices (a pesar
				# de ser sólo columnas) se llama a la función plot sobre
				# la primer columna de cada uno
				'coefRegr' = {
					plot( 1 : nrow(mostrar.grafica.val), mostrar.grafica.val[,1],
	   					xlab = 'Sensor', ylab = 'Regression coefficients',
	   					lwd = 1.5, type = 'l' ) },
				'press.nvl' = , 'fstat.nvl' = ,
				'probFstat.nvl' = {
					plot( 1 : nrow(mostrar.grafica.val), mostrar.grafica.val[,1],
	   					xlab = 'Latent variables used', ylab = 'Value',
					bg = 'black', pch = 20, cex = 1.3 )
					lines(mostrar.grafica.val) },
				'concentPred' = , 'prueba.y' = {
					plot( 1 : nrow(mostrar.grafica.val), mostrar.grafica.val[,1],
   						xlab = 'Sample number', ylab = 'Analyte concentration',
   						bg = 'black', pch = 20, cex = 1.3 )
					lines(mostrar.grafica.val) }
			)
		})}
	})

	# datos estadísticos sobre la calidad de la prediccón
	observe({

		# error asociado a cada muestra
		if (!is.null(INPUT$prueba.y) && !is.null(OUTPUT$concentPred)) {
			   ESTAD$errores <<- INPUT$prueba.y - OUTPUT$concentPred
		} else ESTAD$errores <<- NULL

		# "root mean square error of prediction"
		if (!is.null(ESTAD$errores) && !is.null(INPUT$prueba.y)) {
			   ESTAD$RMSEP <<- sqrt(sum(ESTAD$errores^2) / nrow(INPUT$prueba.y))
		} else ESTAD$RMSEP <<- NULL

		# "relative error of prediction"
		if (!is.null(ESTAD$RMSEP) && !is.null(INPUT$calib.y)) {
			   ESTAD$REP <<- 100 * (ESTAD$RMSEP / mean(INPUT$calib.y))
		} else ESTAD$REP <<- NULL

		output$ESTAD.mostrar.RMSEP <- renderText(ESTAD$RMSEP)
		output$ESTAD.mostrar.REP   <- renderText(ESTAD$REP)

	})

	# visualizaciones de los datos estadísticos sobre la calidad de la prediccón
	observe({

		mostrar.crudo.val <- as.data.frame(switch(input$ESTAD.mostrar.crudo,
			'concentPred.vs.prueba.y' = ESTAD$errores
		))

		output$ESTAD.descargar <- downloadHandler(
			filename = function(){'download.txt'},
			content = function(fname){
				colnames(mostrar.crudo.val) <- NULL
				write.table(reactive(as.matrix(mostrar.crudo.val))(), fname, sep=' ', row.names=FALSE, col.names=FALSE)
			}
		)
		output$ESTAD.mostrar.crudo.figura <- renderDataTable(
			{reactive(mostrar.crudo.val)()},
			options = list(scrollX = TRUE)
		)

		# valores predichos en función de nominales
		if (input$ESTAD.mostrar.grafica == 'concentPred.vs.prueba.y') {
			if ( is.null( OUTPUT$concentPred) || is.null(INPUT$prueba.y)) {
				   output$ESTAD.mostrar.grafica <- NULL }
			else { output$ESTAD.mostrar.grafica <- renderPlot({
				plot( INPUT$prueba.y, OUTPUT$concentPred,
 					xlab = 'Concentraciones Nominales', ylab = 'Predicted concentrations',
				 	bg = 'black', pch = 20, cex = 1.3 )
				abline(0,1)
			})}
		}

		# errores en función de valores predichos
		if (input$ESTAD.mostrar.grafica == 'error.vs.concentPred') {
			if ( is.null( ESTAD$errores) || is.null(INPUT$prueba.y)) {
				   output$ESTAD.mostrar.grafica <- NULL }
			else { output$ESTAD.mostrar.grafica <- renderPlot({
				plot( OUTPUT$concentPred, ESTAD$errores,
					xlab = 'Predicted concentrations', ylab = 'Error',
				 	bg = 'black', pch = 20, cex = 1.3 )
				abline(0,0)
			})}
		}

	})

}

# crea la aplicación shiny con la interfaz gráfica y el servidor
app <- shinyApp(ui = ui, server = server)
