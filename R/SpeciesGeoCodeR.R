# dependencies
pkload <- function(x)
{
  if (!require(x,character.only = TRUE, quietly = T))
  {
    install.packages(x,dep=TRUE, quiet = T, repos='http://cran.us.r-project.org')
    if(!require(x,character.only = TRUE)) stop("Package not found")
  }
}

pkload("rgeos")
pkload("maptools")
pkload("maps")
pkload("mapdata")
pkload("raster")

data(wrld_simpl)

#produces spatialPolygons from text files, or from table, 3 columns: species, lat, long
Cord2Polygon <- function(x){ 
  if (is.character(x)){
    tt <- read.table(x, sep = "\t")
    if (dim(tt)[2] !=  3){
      stop(paste("Wrong input format: \n", 
                 "Inputobject must be a tab-delimited text file or a data.frame with three columns", 
                 sep  = ""))
    }
    if (!is.numeric(tt[, 2]) || !is.numeric(tt[, 3])){
      stop(paste("Wrong input format: \n", 
                 "Input coordinates (columns 2 and 3) must be numeric.", 
                 sep = ""))
    }
    if (!is.character(tt[, 1]) && !is.factor(tt[, 1])){
      warning("Input identifier (column 1) should be a string or a factor.")
    }  
    names(tt) <- c("identifier", "lon", "lat")
    liste <- levels(tt$identifier)
    col <- list()
    for (i in 1:length(liste)){
      pp <- subset(tt, tt$identifier == liste[i])[, c(2, 3)]
      pp <- Polygon(pp)
      po <- Polygons(list(pp), ID = liste[i])
      col[[i]] <- po
    }
    polys <- SpatialPolygons(col, proj4string = CRS("+proj=longlat +datum=WGS84"))
  }else{
    tt <- x
    if (dim(tt)[2] !=  3){
      stop(paste("Wrong input format: \n", 
                 "Inputobject must be a tab-delimited text file or a data.frame with three columns", 
                 sep  = ""))
    }
    if (!is.numeric(tt[, 2]) || !is.numeric(tt[, 3])){
      stop(paste("Wrong input format: \n", 
                 "Input coordinates (columns 2 and 3) must be numeric.", 
                 sep = ""))
    }
    if (!is.character(tt[, 1]) && !is.factor(tt[, 1])){
      warning("Input identifier (column 1) should be a string or a factor.")
    }  
    names(tt) <- c("identifier", "lon", "lat")
    liste <- levels(tt$identifier)
    col <- list()
    for(i in 1:length(liste)){
      pp <- subset(tt, tt$identifier == liste[i])[, c(2, 3)]
      pp <- Polygon(pp)
      po <- Polygons(list(pp), ID = liste[i])
      col[[i]] <- po
    } 
    polys <- SpatialPolygons(col, proj4string = CRS("+proj=longlat +datum=WGS84"))
  }
  return(polys)
}

SpPerPolH <- function(x){
  write("Calculating species number per polygon. \n", stderr()) 
  numpoly <- length(names(x)[-1])
  if(numpoly == 0){
    num_sp_poly <- NULL
  }else{
    pp <- x[, -1]
    pp[pp > 0] <- 1
    if (numpoly > 1){
      num_sp_poly <- data.frame(t(colSums(pp)))
    }else{
      num_sp_poly <- data.frame(sum(pp))
      names(num_sp_poly) <- names(x)[2]
    }
  }
  return(num_sp_poly)
  write("Done", stderr())
}

CoExClassH <- function(x){
  dat <- x
  if(length(dim(dat)) == 0){
    coemat <- "NULL"
  }else{
    if (!is.data.frame(x)){
      stop("Function only defined for class data.frame.")
    }
    if ("identifier" %in% names(dat) ==  F){
      if (T %in% sapply(dat, is.factor)){
        id <- sapply(dat, is.factor)
        old <- names(dat)[id == T]
        names(dat)[id == T] <- "identifier"
        warning(paste("No species identifier found in input object. \n", "Column <", old, "> was used as identifier", sep = ""))
      }
      if (T %in% sapply(dat, is.character)){
        id <- sapply(dat, character)
        old <- names(dat)[id == T]
        names(dat)[id == T] <- "identifier"
        warning(paste("No species identifier found in input object. \n", "Column <", old, "> was used as identifier", sep = ""))
      }
    }
    spnum <- length(dat$identifier)
    numpol <- length(names(dat))
    coemat <- data.frame(matrix(NA, nrow = spnum, ncol = spnum))
    for(j in 1:spnum){
      write(paste("Calculate coexistence pattern for species: ", j, "/", spnum, " ", dat$identifier[j], "\n", sep = ""), stderr())
      sco <- data.frame(dat$identifier)
      for(i in 2:length(names(dat))){
        if (dat[j, i] ==  0) {
          poly<- rep(0, spnum)
          sco <- cbind(sco, poly)
        }
        if (dat[j, i] > 0){
          scoh <- dat[, i]
          if (numpol > 2){
            totocc <- rowSums(dat[j, -1])  
          }else{
            totocc <- dat[j, -1]
          }
          for(k in 1 : length(scoh))
            if (scoh[k] > 0){
              scoh[k] <- dat[j, i]/totocc *100
            }else{
             scoh[k] <- 0
            }
          sco <- cbind(sco, scoh)
        }
      }
      if (numpol >2){
        coex <- rowSums(sco[, -1])
        coemat[j, ] <- coex
      }else{
        coex <- sco[, -1]
        coemat[j, ] <- coex 
      }
    }
    coemat<- cbind(dat$identifier, coemat)
    names(coemat) <- c("identifier", as.character(dat$identifier))
  }
  return(coemat)
}

GetPythonIn <- function(inpt){
  
  coord <- read.table(inpt[1],header = T, sep = "\t")
  idi <- coord[, 1]
  coords <- coord[, c(2, 3)]
  
  polyg <- read.table(inpt[2], header = T, sep = "\t")
  poly <- Cord2Polygon(polyg)
  
  samtab <- read.table(inpt[3], header = T, sep = "\t")
  
  spectab <- read.table(inpt[4], header = T, sep = "\t")
  names(spectab)[1] <- "identifier"
  
  polytab <- SpPerPolH(spectab)
  
  nc <- subset(samtab, is.na(samtab$homepolygon))
  identifier <- idi[as.numeric(rownames(nc))]
  bb <- coords[as.numeric(rownames(nc)), ]
  noclass <- data.frame(identifier, bb)
  
  
  outo <- list(identifier_in = idi, species_coordinates_in = coords, polygons = poly, 
               sample_table = samtab, spec_table = spectab, polygon_table = polytab, 
               not_classified_samples = noclass, coexistence_classified = "NA")
  class(outo) <- "spgeoOUT"
  return(outo)  
}
############################################################################################
#output functions
############################################################################################

WriteTablesSpGeo <- function(x, ...){
  if (class(x) ==  "spgeoOUT"){
    write("Writing sample table: sample_classification_to_polygon.txt. \n", stderr())
    write.table(x$sample_table, file = "sample_classification_to_polygon.txt", sep = "\t", ...)
    write("Writing species occurence table: species_occurences_per_polygon.txt. \n", stderr())
    write.table(x$spec_table, file = "species_occurences_per_polygon.txt", sep =  "\t", ...)
    write("Writing species number per polygon table: speciesnumber_per_polygon.txt. \n", stderr())
    write.table(x$polygon_table, file = "speciesnumber_per_polygon.txt", sep = "\t", ...)
    write("Writing table of unclassified samples: unclassified samples.txt. \n", stderr())
    write.table(x$not_classified_samples, file = "unclassified samples.txt", sep = "\t", ...)
    write("Writing coexistence tables: species_coexistence_matrix.txt. \n", stderr())
    write.table(x$coexistence_classified, file = "species_coexistence_matrix.txt", sep = "\t", ...)
  }else{
    stop("This function is only defined for class spgeoOUT")
  }
}

PlotSpPoly <- function(x, ...){
  if (class(x) ==  "spgeoOUT") {
    num <- length(names(x$polygon_table))
    dat <- sort(x$polygon_table)
    counter <- num/10
    if (length(x$polygon_table) != 0){
      par(mar = c(10, 4, 2, 2))
      barplot(as.matrix(dat[1,]), 
              ylim = c(0, round((max(dat) + max(dat)/4), 0)), 
              ylab = "Number of Species per Polygon", las = 2, ...)
      box("plot")
    }else{
      write("No point in any polygon", stderr())  
    }
  }
  else{
    stop("This function is only defined for class <spgeoOUT>")
  }
}

BarChartSpec <- function(x, mode = c("percent", "total"), plotout = F, ...){
  match.arg(mode)
  if (!class(x) ==  "spgeoOUT" && !class(x) ==  "spgeoH"){
    stop("This function is only defined for class spgeoOUT")
  }
  if(length(x$spec_table) == 0){
    write("No point was found inside the given polygons",stderr())
  }else{
    if (plotout ==  FALSE){par(ask = T)}
    if (mode[1] ==  "total"){
      liste <- x$spec_table$identifier
      leng <-  length(liste)
      par(mar = c(10, 4, 3, 3))
      for(i in 1:leng){
        write(paste("Creating barchart for species ", i, "/", leng, ": ", liste[i], "\n", sep = ""), stderr())
        spsub <- as.matrix(subset(x$spec_table, x$spec_table$identifier ==  liste[i])[, 2:dim(x$spec_table)[2]])
        if (sum(spsub) > 0){
          barplot(spsub, las = 2, ylim = c(0, (max(spsub) + max(spsub) / 10)), 
                  ylab = "Number of occurrences", ...)
          title(liste[i])
        }
      }
    }
    if (mode[1] ==  "percent"){
      percent <- x$spec_table[, -1]
      anzpoly <-length(names(x$spec_table)[-1]) 
      if (anzpoly > 1){
        percent2  <- percent / rowSums(percent) * 100
      }else{
        percent2  <- percent / sum(percent) * 100
      }
      percent2[percent2 ==  "NaN"] <- 0
      percent2 <- data.frame(identifier = x$spec_table[, 1], percent2)
    
      liste <- x$spec_table$identifier
      leng <-  length(liste)
      leng2 <- length(colnames(percent2))
      par(mar = c(10, 4, 3, 3))
      for(i in 1:leng){
        write(paste("Creating barchart for species ", i, "/", leng, ": ", liste[i], "\n", sep = ""), stderr())
        if (anzpoly > 1){
          spsub <- as.matrix(subset(percent2, percent2$identifier ==  liste[i])[, 2:leng2])
        }else{
          spsub <- as.matrix(percent2[percent2$identifier ==  liste[i], ][, 2:leng2])
          names(spsub) <- names(x$spec_table)[-1]
        }
        if (sum(spsub) > 0){
          barplot(spsub, las = 2, ylim = c(0, (max(spsub) + max(spsub) / 10)), 
                  ylab = "Percent of occurrences", names.arg = names(spsub), ...)
          title(liste[i])
        }
      }
    }  
    par(ask = F)
  }
}

BarChartPoly <- function(x, plotout = F, ...){
  if (!class(x) ==  "spgeoOUT" && !class(x) ==  "spgeoH"){
    stop("This function is only defined for class spgeoOUT")
  }  
  if (plotout ==  FALSE){par(ask = T, mar = c(15, 4, 3, 3))}
  liste <- names(x$spec_table)
  leng <- length(liste)
  par(mar = c(15, 4, 3, 3))
  if(length(names(x$spec_table)) == 0){
    cat("No point fell in any polygon")
  }else{
    for(i in 2:leng){
      write(paste("Creating barchart for polygon ", i-1, "/", leng, ": ", liste[i], "\n", sep = ""), stderr())
      subs <-subset(x$spec_table, x$spec_table[, i] > 0)
      datsubs <- subs[order(subs[, i]),]
      if(dim(subs)[1] == 0){
        plot(1:10,1:10,type = "n", xlab = "", ylab = "Number of occurences", )
        text(3,6, labels = "No species occurred in this polygon.", adj = 0)
        title(liste[i])
      }else{
       barplot(datsubs[, i], names.arg = datsubs$identifier, 
               las = 2, ylab = "Number of occurences",cex.names = .7)#, ...)
       title(liste[i])
      }
    }
  }
  par(ask = F)

}

HeatPlotCoEx <- function(x, ...){
  
  if (class(x) ==  "spgeoOUT" ){
    dat <- x$coexistence_classified
  }else{ 
    dat <- x
  }
    if (class(dat) !=  "data.frame"){
      stop("Wrong input format. Input must be a data.frame.")
    }
    if (dim(dat)[2] !=  (dim(dat)[1] + 1)){
      warning("Suspicous data dimensions, check input file.")
    }
    ymax <- dim(dat)[1]
    xmax <- dim(dat)[2]
    colo <- rev(heat.colors(10))
    numer <- rev(1:ymax)
  
    layout(matrix(c(rep(1, 9), 2), ncol = 1, nrow = 10))
    par(mar =  c(0, 10, 10, 0))
    plot(0, xlim = c(0, xmax - 1), ylim = c(0, ymax) , type = "n", axes = F, xlab = "", ylab = "")
    for(j in 2:xmax ){
      write(paste("Ploting coexistence for species ", j, "/", xmax, ": ", colnames(dat)[j],"\n", sep = ""), stderr())
      for(i in 1:ymax){
        if (i ==  (j - 1)){
          rect(j - 2, numer[i] - 1 , j - 1, numer[i], col = "black" )
        }else{
          ind <- round(dat[i, j]/10, 0)
          if (ind ==  0) {
            rect(j - 2, numer[i]-1, j - 1, numer[i], col = "white" )
          }else{
            rect(j - 2, numer[i]-1 , j - 1, numer[i], col = colo[ind] )
          }
        }
      }
    }
    axis(side = 3, at = seq(0.5, (xmax - 1.5)), labels = colnames(dat)[-1], las = 2, cex.axis = .7, pos = ymax)
    axis(2, at = seq(0.5, ymax), labels = rev(dat$identifier), las = 2, cex.axis = .7, pos =  0)
    title("Species co-occurrence", line = 9)
  
    par(mar = c(0.5, 10, 0, 0))
    plot(c(1, 59), c(1, 12), type = "n", axes = F, ylab  = "", xlab = "")
    text(c(13, 13), c(10, 7), c("0%", "10%"))
    text(c(20, 20), c(10, 7), c("20%", "30%"))
    text(c(27, 27), c(10, 7), c("40%", "50%"))
    text(c(34, 34), c(10, 7), c("60%", "70%"))
    text(c(41, 41), c(10, 7), c("80%", "90%"))
    text(c(48), 10, "100%")
    rect(c(9, 9, 16, 16, 23, 23, 30, 30, 37, 37, 44), c(rep(c(10.7, 7.7), 5), 10.7), 
         c(11, 11, 18, 18, 25, 25, 32, 32, 39, 39, 46), c(rep(c(8.7, 5.7), 5), 8.7), 
         col = c("white", colo))
    rect(7, 5, 51, 12)
}

MapPerPoly <- function(x, scale, plotout = FALSE){
  if (!class(x) ==  "spgeoOUT"){
    stop("This function is only defined for class spgeoOUT")
  }
  dum <- x$polygons
  if(class(dum) == "SpatialPolygonsDataFrame")
    {
     if(scale == "ECOREGION"){liste1 <- liste2 <- unique(dum$ECO_NAME)}
     if(scale == "BIOME")
     {
       liste1  <- liste2 <- unique(dum$BIOME)
       indbiome <- cbind(c( "Tropical and Subtropical Moist Broadleaf Forests", 
                            "Tropical and Subtropical Dry Broadleaf Forests", 
                            "Tropical and Subtropical Coniferous Forests", 
                            "Temperate Broadleaf and Mixed Forests", 
                            "Temperate Conifer Forests", 
                            "Boreal Forests/Taiga", 
                            "Tropical and Subtropical Grasslands and Savannas and Shrublands", 
                            "Temperate Grasslands and Savannas and Shrublands", 
                            "Flooded Grasslands and Savannas", 
                            "Montane Grasslands and Shrublands", 
                            "Tundra", 
                            "Mediterranean Forests, Woodlands and Scrub", 
                            "Deserts and Xeric Shrublands", 
                            "Mangroves"), c(1:14))
       for(i in 1: dim(indbiome)[1])
       {
         liste1[liste1 == indbiome[i,2]] <- indbiome[i,1]
       }
     }
     if(scale == "REALM")
     {
       liste1  <- liste2 <- as.character(unique(dum$REALM))
       indrealm <- cbind(c("Australasia", "Antarctic", 
                           "Afrotropics", "IndoMalay", 
                           "Nearctic", "Neotropics", 
                           "Oceania", "Palearctic"), 
                         c("AA", "AN", "AT", "IM", "NA", "NT", "OC", "PA"))
       for(i in 1: dim(indrealm)[1])
       {
         liste1[liste1 == indrealm[i,2]] <- indrealm[i,1]
       }
     }   
     len <- length(liste1)
  }else{
    len <- length(names(dum))
  }
    for(i in 1:len){
      if(class(dum) == "SpatialPolygonsDataFrame"){
        write(paste("Creating map for polygon ", i,"/",length(liste1), ": ", liste1[i], "\n",sep = ""), stderr())
        chopo <- liste1[i]
        if(scale == "ECOREGION")
        {
          xmax <- min(max(bbox(subset(dum,dum$ECO_NAME == liste1[i]))[1, 2]) + 5, 180)
          xmin <- max(min(bbox(subset(dum,dum$ECO_NAME == liste1[i]))[1, 1]) - 5, -180)
          ymax <- min(max(bbox(subset(dum,dum$ECO_NAME == liste1[i]))[2, 2]) + 5, 90)
          ymin <- max(min(bbox(subset(dum,dum$ECO_NAME == liste1[i]))[2, 1]) - 5, -90)
        }
        if(scale == "BIOME")
        {
          xmax <- min(max(bbox(subset(dum,dum$BIOME == liste2[i]))[1, 2]) + 5, 180)
          xmin <- max(min(bbox(subset(dum,dum$BIOME == liste2[i]))[1, 1]) - 5, -180)
          ymax <- min(max(bbox(subset(dum,dum$BIOME == liste2[i]))[2, 2]) + 5, 90)
          ymin <- max(min(bbox(subset(dum,dum$BIOME == liste2[i]))[2, 1]) - 5, -90)
        }
        if(scale == "REALM")
        {
          xmax <- min(max(bbox(subset(dum,dum$REALM == liste2[i]))[1, 2]) + 5, 180)
          xmin <- max(min(bbox(subset(dum,dum$REALM == liste2[i]))[1, 1]) - 5, -180)
          ymax <- min(max(bbox(subset(dum,dum$REALM == liste2[i]))[2, 2]) + 5, 90)
          ymin <- max(min(bbox(subset(dum,dum$REALM == liste2[i]))[2, 1]) - 5, -90)
        }
          
       }else{
        write(paste("Creating map for polygon ", i,"/",length(names(dum)), ": ", names(dum)[i], "\n",sep = ""), stderr())
        chopo <- names(dum)[i]

        xmax <- min(max(bbox(x$polygons[i])[1, 2]) + 5, 180)
        xmin <- max(min(bbox(x$polygons[i])[1, 1]) - 5, -180)
        ymax <- min(max(bbox(x$polygons[i])[2, 2]) + 5, 90)
        ymin <- max(min(bbox(x$polygons[i])[2, 1]) - 5, -90)
       }
              
    subpo <- subset(x$sample_table, as.character(x$sample_table$homepolygon) ==  as.character(chopo))
    subpo <- subpo[order(subpo$identifier), ]  
    
    liste <- unique(subpo$identifier)
    leng <- length(liste)

    rain <- rainbow(leng)
    ypos <- vector(length = leng)
    yled <- (ymax - ymin) * 0.025
    for(k in 1:leng){
      ypos[k]<- ymax - yled * k
    }
    
    layout(matrix(c(1, 1, 1, 1,1, 2, 2), ncol =  7, nrow = 1))
    par(mar = c(3, 3, 3, 0))
    te <-try(map("world", xlim = c(xmin, xmax), ylim = c(ymin, ymax)), silent = T)
    if(class(te) == "try-error"){map("world")}
    axis(1)
    axis(2)
    box("plot")
    title(chopo)
    if(class(dum) == "SpatialPolygonsDataFrame")
      {
        if(scale == "ECOREGION"){plot(subset(dum,dum$ECO_NAME == liste1[i]), col = "grey60", add = T)}
        if(scale == "BIOME"){plot(subset(dum,dum$BIOME == liste2[i]), col = "grey60", add = T)}
        if(scale == "REALM"){plot(subset(dum,dum$REALM == liste2[i]), col = "grey60", add = T)}
      }else{
      plot(x$polygons[i], col = "grey60", add = T)
      }
    for(j in 1:leng){
      subsub <- subset(subpo,subpo$identifier == liste[j]) 
      points(subsub[,3], subsub[,4], 
             cex = 1, pch = 3 , col = rain[j])
      }
    #legend
    write("Adding legend \n", stderr())
    par(mar = c(3, 0, 3, 0), ask = F)
    plot(c(1, 50), c(1, 50), type = "n", axes = F)
    if(leng == 0){
      yset <- 25
      xset <- 1}
    if (leng ==  1){
      yset <- 25
      xset <- rep(4, leng)
    }
    if(leng >  1){
      yset <- rev(sort(c(seq(25, 25 + max(ceiling(leng/2) - 1, 0)), 
                         seq(24, 24 - leng/2 + 1))))
      xset <- rep(4, leng)
    }
    points(xset-2, yset, pch =  3, col = rain)
    if(leng == 0){
      text(xset, yset, labels = "No species found in this polygon", adj = 0)
    }else{
      text(xset, yset, labels =  liste, adj = 0, xpd = T)
      rect(min(xset) - 4, min(yset) -1, 50 + 1, max(yset) + 1, xpd = T)
    }
    
    if (plotout ==  FALSE){par(ask = T)}
  }
  par(ask = F)
}

MapPerSpecies <- function(x, moreborders = F, plotout = FALSE, ...){
  if (!class(x) ==  "spgeoOUT"){
    stop("This function is only defined for class spgeoOUT")
  }
  layout(matrix(c(1, 1, 1, 1), ncol = 1, nrow = 1))
  if (plotout ==  FALSE){par(ask = T)}
  dat <- x$sample_table
  liste <- levels(dat$identifier)
  alle <- data.frame(identifier = x$identifier_in, x$species_coordinates_in)
    
  for(i in 1:length(liste)){
    write(paste("Mapping species: ", i, "/", length(liste), ": ", liste[i], "\n",sep = ""), stderr())
    kk <- subset(dat, dat$identifier ==  liste[i])

    inside <- kk[!is.na(kk$homepolygon),]
    outside <- subset(alle, alle$identifier == liste[i])
    
    xmax <- min(max(alle$XCOOR) + 2, 180)
    xmin <- max(min(alle$XCOOR) - 2, -180)
    ymax <- min(max(alle$YCOOR) + 2, 90)
    ymin <- max(min(alle$YCOOR) - 2, -90)
    
    map ("world", xlim = c(xmin, xmax), ylim = c(ymin, ymax))
    axis(1)
    axis(2)
    title(liste[i])
    if (moreborders == T) {plot(wrld_simpl, add = T)}
    plot(x$polygons, col = "grey60", add = T)
    points(outside$XCOOR, outside$YCOOR, 
            cex = 0.7, pch = 3 , col = "red")
    if(length(inside) > 0){
      points(inside$XCOOR, inside$YCOOR, 
             cex = 0.7, pch = 3 , col = "blue")
    }

    box("plot")
  }
  par(ask = F)
}

MapAll <- function(x, polyg, moreborders = F, ...){
  data(wrld_simpl)
  if (class(x) ==  "spgeoOUT"){
    xmax <- min(max(x$species_coordinates_in[, 1]) + 2, 180)
    xmin <- max(min(x$species_coordinates_in[, 1]) - 2, -180)
    ymax <- min(max(x$species_coordinates_in[, 2]) + 2, 90)
    ymin <- max(min(x$species_coordinates_in[, 2]) - 2, -90)
    difx <- sqrt(xmax^2 + xmin^2)
    dify <- sqrt(ymax^2 + ymin^2)  
    if(difx > 90){
      xmax <- min(xmax +10, 180)
      xmin <- max(xmin -10,-180)
      ymax <- min(ymax +10, 90)
      ymin <- max(ymin -10,-90)
    }
    write("Creating map of all samples. \n", stderr())
    map ("world", xlim = c(xmin, xmax), ylim = c(ymin, ymax))
    axis(1)
    axis(2)
    box("plot")
    title("All samples")
    if (moreborders ==  T) {plot(wrld_simpl, add = T)}
    write("Adding polygons. \n", stderr())
    plot(x$polygons, col = "grey60", border = "grey40", add = T, ...)
    write("Adding sample points \n", stderr())
    points(x$species_coordinates_in[, 1], x$species_coordinates_in[, 2], 
           cex = 0.7, pch = 3 , col = "blue", ...)
  }
  if (class(x) ==  "matrix" || class(x) ==  "data.frame"){
    if (!is.numeric(x[, 1]) || !is.numeric(x[, 2])){
      stop(paste("Wrong input format:\n", 
                 "Point input must be a <matrix> or <data.frame> with 2 columns.\n", 
                 "Column order must be lon - lat.", sep = ""))
    }
    if (class(polyg) !=  "SpatialPolygons"){
      warning("To plot polygons, polyg must be of class <SpatialPolygons>.")
    }
    x <- as.data.frame(x)
    nums <- sapply(x, is.numeric)
    x<- x[, nums]
    xmax <- min(max(x[, 2]) + 2, 180)
    xmin <- max(min(x[, 2]) - 2, -180)
    ymax <- min(max(x[, 1]) + 2, 90)
    ymin <- max(min(x[, 1]) - 2, -90)
    if (ymax > 92 || ymin < -92){
      warning("Column order must be lon-lat, not lat - lon. Please check")
    }
    map ("world", xlim = c(xmin, xmax), ylim = c(ymin, ymax))
    axis(1)
    axis(2)
    title("All samples")
    box("plot")
    if (moreborders ==  T) {plot(wrld_simpl, add = T, ...)}
    if(class(polyg == "list"))

      plot(polyg, col = "grey60", add = T, ...)

    points(x[, 2], x[, 1], 
           cex = 0.5, pch = 3 , col = "blue", ...)
    
  }
}

MapUnclassified <- function(x, moreborders = F, ...){
  if (!class(x) ==  "spgeoOUT"){
    stop("This function is only defined for class spgeoOUT")
  }
  dat <- data.frame(x$not_classified_samples)
  if (dim(dat)[1] ==  0){
    plot(c(1:20), c(1:20), type  = "n", axes = F, xlab = "", ylab = "")
    text(10, 10, labels = paste("All points fell into the polygons\n
                                and were classified.\n", 
                                "No unclassified points", sep = ""))
  }else{
    xmax <- min(max(dat$XCOOR) + 2, 180)
    xmin <- max(min(dat$XCOOR) - 2, -180)
    ymax <- min(max(dat$YCOOR) + 2, 90)
    ymin <- max(min(dat$YCOOR) - 2, -90)
    
    write("Creating map of unclassified samples. \n", stderr())
    map ("world", xlim = c(xmin, xmax), ylim = c(ymin, ymax), ...)
    axis(1)
    axis(2)
    title("Samples not classified to polygons \n")
    if (moreborders == T) {plot(wrld_simpl, add = T)}
    write("Adding polygons \n", stderr())
    if(class(x$polygons) == "list"){
      plota <- function(x){plot(x, add = T, col = "grey60", border = "grey40")}
      lapply(x$polygons, plota)
    }else{
      plot(x$polygons, col = "grey60", border = "grey40", add = T, ...)
    }
    write("Adding sample points \n", stderr())
    points(dat$XCOOR, dat$YCOOR, 
           cex = 0.5, pch = 3 , col = "red", ...)
    box("plot")
  }
}  

OutMapAll <- function(x, ...){
  write("Creating overview map: map_samples_overview.pdf. \n", stderr())
  pdf(file = "map_samples_overview.pdf", paper = "special", width = 10.7, height = 7.2, onefile = T, ...)
  MapAll(x, ...)
  MapUnclassified(x, ...)
  dev.off()
}

OutMapPerPoly <- function(x, ...){
  write("Creating map per polygon: map_samples_per_polygon.pdf. \n", stderr())
  pdf(file = "map_samples_per_polygon.pdf", paper = "special", width = 10.7, height = 7.2, onefile = T)
  MapPerPoly(x,scale = scale, plotout = T)
  dev.off()
}

OutMapPerSpecies <- function(x){
  write("Creating map per species: map_samples_per_species.pdf. \n", stderr())
  pdf(file = "map_samples_per_species.pdf",paper = "special", width = 10.7, height = 7.2, onefile = T)
  MapPerSpecies(x, plotout = T)
  dev.off()
}

OutBarChartSpec <- function(x, ...){
  write("Creating barchart per species: barchart_per_species.pdf. \n", stderr())
  pdf(file = "barchart_per_species.pdf", paper = "special", width = 10.7, height = 7.2, onefile = T)
  BarChartSpec(x, plotout = T, mode = "percent", ...)
  dev.off()
}

OutBarChartPoly <- function(x, ...){
  write("Creating barchart per polygon: barchart_per_polygon.pdf. \n", stderr())
  pdf(file = "barchart_per_polygon.pdf",paper = "special", width = 10.7, height = 7.2, onefile = T)
  BarChartPoly(x, plotout = T, cex.axis = .8, ...)
  dev.off()
}

OutHeatCoEx <- function(x, ...){
  write("Creating coexistence heatplot: heatplot_coexistence.pdf. \n", stderr())
  pdf(file = "heatplot_coexistence.pdf",paper = "special", width = 10.7, height = 7.2, onefile = T)
  HeatPlotCoEx(x, ...)
  dev.off()
}

OutPlotSpPoly <- function(x, ...){
  write("Creating species per polygon barchart: number_of_species_per_polygon.pdf. \n", stderr())
  pdf(file = "number_of_species_per_polygon.pdf",paper = "special", width = 10.7, height = 7.2, onefile = T)
  PlotSpPoly(x, ...)
  dev.off()
}