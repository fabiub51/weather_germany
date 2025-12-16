library(tidyverse)
library(readr)
library(janitor)
library(zyp)
library(zoo)
library(stats)

data_dir <- file.path("./data")
all_files <- list.files(data_dir)
LEN <- length(all_files)

START_REF <- 1961
END_REF <- 1990
BAND <- 15 

complete_df <- data.frame()
widths <- c(5, 9, 9, 15, 12, 10, 42, 40, 5)
stationen <- read.fwf("stationen.txt", skip = 2, widths = widths)

colnames(stationen) <- c("STATIONS_ID", 
                         "von",
                         "bis", 
                         "hoehe",
                         "breite",
                         "laenge",
                         "name",
                         "bundesland", 
                         "abgabe")

stationen$STATIONS_ID <- sprintf("%05d", stationen$STATIONS_ID)

for (i in 1:LEN){
  df <- read_delim(file.path(data_dir,all_files[i]), show_col_types = FALSE)
  df$STATIONS_ID <- as.numeric(df$STATIONS_ID)
  df$STATIONS_ID <- sprintf("%05d", df$STATIONS_ID)
  print(unique(df$STATIONS_ID))

  STAT_ID <- unique(df$STATIONS_ID)
  LON <- unique(stationen %>% filter(STATIONS_ID == STAT_ID) %>%  pull(laenge))
  LAT <- unique(stationen %>% filter(STATIONS_ID == STAT_ID) %>%  pull(breite))
  
  df <- df %>% 
    left_join(stationen, by="STATIONS_ID") %>% 
    select(MESS_DATUM, 
           breite, 
           laenge, 
           name, 
           TXK = ` TXK`, 
           TGK = ` TGK`, 
           TMK = ` TMK`, 
           RSK = ` RSK`, 
           UPM = ` UPM`, 
           bundesland) %>% 
    mutate(TXK = as.numeric(TXK))
  
  df$MESS_DATUM <- ymd(df$MESS_DATUM)
  
  # Step 1 - find first recording of TXK
  start_date <- df %>% 
    filter(TXK > -999) %>% 
    summarize(TXK_begin = min(MESS_DATUM)) %>% 
    pull(TXK_begin)
  
  if (year(start_date) > year(START_REF)+5){
    next
  }
  
  # Step 2 - Impute missing data (mean of last three years )
  
  impute_df <- df %>% 
    filter(MESS_DATUM >= start_date) %>% 
    mutate(doy = yday(MESS_DATUM), 
           Jahr = year(MESS_DATUM), 
           last_year = lag(TXK, 365),
           two_years = lag(TXK, 730), 
           three_years = lag(TXK, 1095), 
           last_three_years = mean(c(last_year, two_years, three_years), na.rm=TRUE), 
           TXK = if_else(TXK == -999, last_three_years, TXK), 
           TXK = if_else(is.na(TXK), last_three_years, TXK))
  
  # Step 3 - Calculation of heat days
  
  # Step 3.1 - Generate reference period quantiles
  
  quantile_df <- impute_df %>% 
    mutate(TXK_lag1 = lag(TXK,1), 
           TXK_lag2 = lag(TXK,2), 
           TXK_lag3 = lag(TXK,3), 
           TXK_lag4 = lag(TXK,4), 
           TXK_lag5 = lag(TXK,5), 
           TXK_lag6 = lag(TXK,6), 
           TXK_lag7 = lag(TXK,7), 
           TXK_lag8 = lag(TXK,8), 
           TXK_lag9 = lag(TXK,9), 
           TXK_lag10 = lag(TXK,10),
           TXK_lag11 = lag(TXK,11), 
           TXK_lag12 = lag(TXK,12), 
           TXK_lag13 = lag(TXK,13), 
           TXK_lag14 = lag(TXK,14), 
           TXK_lag15 = lag(TXK,15),
           
           TXK_lead1 = lead(TXK,1), 
           TXK_lead2 = lead(TXK,2), 
           TXK_lead3 = lead(TXK,3), 
           TXK_lead4 = lead(TXK,4), 
           TXK_lead5 = lead(TXK,5), 
           TXK_lead6 = lead(TXK,6), 
           TXK_lead7 = lead(TXK,7), 
           TXK_lead8 = lead(TXK,8), 
           TXK_lead9 = lead(TXK,9), 
           TXK_lead10 = lead(TXK,10),
           TXK_lead11 = lead(TXK,11), 
           TXK_lead12 = lead(TXK,12), 
           TXK_lead13 = lead(TXK,13), 
           TXK_lead14 = lead(TXK,14), 
           TXK_lead15 = lead(TXK,15)) %>% 
    pivot_longer(cols = matches("^TXK"), names_to="TXK_value", values_to = "vals") %>% 
    group_by(doy) %>% 
    summarize(txk_quant = quantile(vals, 0.98, na.rm = TRUE))
  
  # Step 3.2 - Join data and calculate heat-days
  heat_days <- impute_df %>% 
    mutate(season = case_when(
      month(MESS_DATUM) %in% c(1,2,12) ~ 1,
      month(MESS_DATUM) %in% c(3,4,5) ~ 2,
      month(MESS_DATUM) %in% c(6,7,8) ~ 3,
      month(MESS_DATUM) %in% c(1,2,12) ~ 4
    )) %>% 
    filter(year(MESS_DATUM) > END_REF) %>% 
    left_join(quantile_df, by= "doy") %>% 
    select(MESS_DATUM, doy, TXK, txk_quant, season) %>% 
    mutate(heat_day = if_else(TXK > txk_quant & TXK > 28, 1, 0))
  
  # Step 3.3 - Calculate number of consecutive heat days and heat waves
  r <- rle(heat_days$heat_day)
  consecutive_heat <- rep(ifelse(r$values==1, r$lengths, 0), r$lengths)
  
  heat_days$consecutive_heat <- consecutive_heat
  
  heat_days %>% 
    mutate(heat_wave = if_else(consecutive_heat >= 3,1,0),
           heat_wave_rat = if_else(consecutive_heat >2,heat_wave/consecutive_heat,0)) %>% 
    group_by(Jahr = year(MESS_DATUM)) %>% 
    summarize(heat_wave_length = max(consecutive_heat), 
              sum_heat_days = sum(heat_day),
              n_heat_waves = sum(heat_wave_rat)) %>% 
    ggplot(aes(x=Jahr, y= n_heat_waves))+
    geom_point(aes(x=Jahr, y= heat_wave_length), color = "blue")+
    geom_point(aes(x=Jahr, y = sum_heat_days), color = "red")+
    geom_point()
  
  # Step 3.4 - Summary for this station
  summary_df <- heat_days %>% 
    mutate(heat_wave = if_else(consecutive_heat >= 3,1,0),
           heat_wave_rat = if_else(consecutive_heat >2,heat_wave/consecutive_heat,0)) %>% 
    group_by(Jahr = year(MESS_DATUM)) %>% 
    summarize(heat_wave_length = max(consecutive_heat), 
              sum_heat_days = sum(heat_day),
              n_heat_waves = sum(heat_wave_rat))
  
  summary_df$id <- STAT_ID
  summary_df$lon <- LON
  summary_df$lat <- LAT
  
  complete_df <- rbind(complete_df, summary_df)

}

complete_df %>% 
  ggplot(aes(x=lon, y=lat))+
  geom_point()

# Mann Kendall Test for number of heat days, length of heat waves, number of heat waves per year
mk_heat_days <- complete_df %>% 
  group_by(id) %>% 
  summarize(tau = MannKendall(sum_heat_days)$tau, 
            p = MannKendall(sum_heat_days)$sl)

mk_heat_wave_length <- complete_df %>% 
  group_by(id) %>% 
  summarize(tau = MannKendall(heat_wave_length)$tau, 
            p = MannKendall(heat_wave_length)$sl)

mk_number_heat_waves <- complete_df %>% 
  group_by(id) %>% 
  summarize(tau = MannKendall(n_heat_waves)$tau, 
            p = MannKendall(n_heat_waves)$sl)

# Join results, coordinates
final_df <- mk_heat_days %>% 
  left_join(mk_heat_wave_length, by = "id", suffix = c("_days", "_length")) %>% 
  left_join(mk_number_heat_waves, by = "id") %>% 
  left_join(stationen %>% select(id = STATIONS_ID, lon = laenge, lat = breite), by = "id")

# Adjust for multiple comparisons

final_df <- final_df %>% 
  mutate(p_days_adj = p.adjust(p_days, method = "BH"),
         p_length_adj = p.adjust(p_length, method = "BH"),
         p_number_adj = p.adjust(p, method = "BH"), 
         days_sig = if_else(p_days_adj < 0.05, 1, 0),
         length_sig = if_else(p_length_adj < 0.05, 1, 0),
         num_sig = if_else(p_number_adj < 0.05, 1, 0))

write_csv(final_df, file.path(data_dir, "export.csv"))

library(writexl)
write_xlsx(final_df, file.path(data_dir, "export.xlsx"))

sig_stations <- final_df %>% 
  filter(p_days_adj < 0.05|
         p_length_adj < 0.05|
         p_number_adj < 0.05) %>% 
  ggplot(aes(x = lon, y = lat, color = tau_days))+
  geom_point()
         