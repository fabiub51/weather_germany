library(tidyverse)
library(rvest)   
library(stringr) 

widths <- c(5, 9, 9, 15, 12, 10, 42, 40, 5)
stationen <- read.fwf("stationen.txt", skip = 2, widths = widths)

colnames(stationen) <- c("id", 
                         "von",
                         "bis", 
                         "hoehe",
                         "breite",
                         "laenge",
                         "name",
                         "bundesland", 
                         "abgabe")

# Convert to character with exactly 5 digits
stationen$id <- sprintf("%05d", stationen$id)

stationen$von <- ymd(stationen$von)
stationen$bis <- ymd(stationen$bis)

stationen_aktuell <- stationen %>% 
  filter(year(bis) >= 2024)


base_url <- "https://opendata.dwd.de/climate_environment/CDC/observations_germany/climate/daily/kl/historical/"

page <- read_html(base_url)

links <- page %>% html_nodes("a") %>% html_attr("href")

zip_files <- links[str_detect(links, "\\.zip$")]

zip_dir <- paste0(getwd(),"/zip/")
data_dir <- paste0(getwd(),"/data/")

station_ids <- unique(stationen_aktuell$id)

for (i in 1:length(station_ids)){
  file_to_download <- zip_files[str_detect(zip_files, paste0("_", station_ids[i], "_"))]
  file_to_download
  
  if(length(file_to_download) == 1) {
    url <- paste0(base_url, file_to_download)
    destfile <- paste0(zip_dir, file_to_download)
    
    download.file(url, destfile, mode = "wb")
    cat("Downloaded:", destfile, "\n")
  } else {
    cat("No file or multiple files matched the station id.\n")
  }
  
  unzip(destfile, exdir = zip_dir)
  
  current_files <- list.files(zip_dir)
  
  current_files[str_detect(current_files, "produkt")]
  
  file.rename(from=paste0(zip_dir,current_files[str_detect(current_files, "produkt")]),
              to=paste0(data_dir, current_files[str_detect(current_files, "produkt")]))
  
  unlink(paste0(zip_dir,"*"))
  
  Sys.sleep(10)
}


