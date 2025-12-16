## Project README: Climate Change Analysis - Heat Waves

This project contains R scripts for downloading, processing, and statistically analyzing climate data from the German Weather Service (Deutscher Wetterdienst, DWD) to study heat wave trends. The final output is used to populate a dynamic dashboard.

### Overview

The primary goal of this project is to analyze the trend in heat-related events (specifically **heat days**, **heat wave length**, and **number of heat waves**) at various climate stations in Germany.

The analysis involves:
1.  Downloading historical daily climate data (specifically maximum air temperature, TXK) from the DWD server for selected active stations.
2.  Data cleaning, imputation of missing values, and definition of heat days and heat waves based on historical quantiles.
3.  Application of the **Mann-Kendall trend test** to determine significant temporal trends in heat event metrics.
4.  Exporting the results for visualization in a Tableau dashboard.

### Dashboard Link

The results of this analysis are visualized in the following interactive Tableau Public dashboard:

> **[Heat Wave Analysis Dashboard](https://public.tableau.com/views/HeatWaveAnalysis_17658388012280/HeatWaves?:language=de-DE&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)**

---

### Project Structure

├── data/                               # Directory for processed and final data outputs
│   ├── export.csv                      # Final statistical results (trend test outputs)
│   ├── export.xlsx                     # Final statistical results (Excel format)
|   └── produkt_*.txt                   # Data for individual weather stations 
├── zip/                                # Temporary directory for raw downloaded ZIP files
├── scripts/                            # Directory for R scripts handling download and data processing
│   ├── data_generation.R               # R script: Handles data download from DWD and extraction
│   └── statistical_analysis.R          # R script: Performs statistical analysis (imputation, heat wave calculation, Mann-Kendall test)
├── stationen.txt                       # DWD metadata: List of all climate stations (ID, coordinates, period)
└── README.md                           # This overview and project documentation

### Project Files

The project consists of the following key files:

| File Name | Description |
| :--- | :--- |
| `data_generation.R` | Script to download station metadata (`stationen.txt`) and historical daily climate data (`kl/historical`) from DWD. |
| `statistical_analysis.R` | Script for data processing, calculation of heat wave metrics, trend analysis using the Mann-Kendall test, and final data export. |
| `stationen.txt` | A fixed-width format (FWF) file containing metadata for all DWD climate stations (ID, coordinates, period of operation, etc.). This is downloaded by `data_generation.R`. |
| `zip/` (directory) | Temporary directory for storing downloaded raw `.zip` files. |
| `data/` (directory) | Directory for storing the extracted product files and the final output `export.csv`/`export.xlsx`. |

---

### Setup and Usage

#### 1. Prerequisites

The following software and R packages are required to run the scripts:

* **R** (Programming Language)
* **RStudio** (Recommended IDE)
* **R Packages** (Installed via `install.packages()`):
    * `tidyverse`
    * `rvest`
    * `stringr`
    * `readr`
    * `janitor`
    * `zyp` (for the Mann-Kendall test)
    * `zoo`
    * `stats`
    * `writexl`

#### 2. Running the Data Generation Script

The `data_generation.R` script handles the downloading of necessary climate data.

1.  **Ensure Directories Exist:** Create the `zip` and `data` directories in your project's root folder.
2.  **Run:** Execute `data_generation.R`.
    * This script first reads the `stationen.txt` file (assumed to be available in the root folder).
    * It filters for currently active stations (those with an 'until' year $\ge 2024$).
    * It then iterates through the active stations, downloading the corresponding historical daily climate data `.zip` file from the DWD server into the `zip/` directory.
    * The relevant product file is unzipped and moved to the `data/` directory.
    * A `Sys.sleep(10)` command is included to space out the downloads and be considerate of the DWD server load.

#### 3. Running the Statistical Analysis Script

The `statistical_analysis.R` script performs all calculations and trend testing.

1.  **Run:** Execute `statistical_analysis.R`.
2.  **Processing Steps:** For each station file in the `data/` directory, the script performs the following:
    * **Data Import & Filtering:** Imports the data and checks if the station has sufficiently long records (starting within 5 years after the reference start, **1961**).
    * **Imputation:** Missing maximum temperature (`TXK = -999`) values are imputed using the mean of the same calendar day's reading over the last three preceding years.
    * **Heat Day Definition:** A **heat day** is defined as a day where the maximum temperature (`TXK`) is **greater than $28^\circ \text{C}$** AND **above the 98th percentile** of the historical temperature distribution for that specific day of the year (calculated within a $\pm 15$ day rolling window from the **1961-1990 reference period**). 
    > **[Heat Wave Definition by DWD](https://www.dwd.de/DE/service/lexikon/Functions/glossar.html?lv3=624852&lv2=101094)**
    * **Heat Wave Definition:** A **heat wave** is defined as a period of **3 or more consecutive heat days**.
    * **Trend Analysis:** The non-parametric **Mann-Kendall test** is applied to the time series of yearly:
        * Total number of heat days (`sum_heat_days`)
        * Maximum heat wave length (`heat_wave_length`)
        * Number of heat waves (`n_heat_waves`)
    * **Multiple Comparisons Correction:** P-values are adjusted using the **Benjamini-Hochberg (BH) method** to control the False Discovery Rate.
3.  **Output:** The final results, including the Mann-Kendall $\tau$ and adjusted $p$-values for all three metrics for each station, are saved to:
    * `data/export.csv`
    * `data/export.xlsx`

### Key Libraries and Functions Used

* **`zyp::MannKendall(x)`:** Calculates the Mann-Kendall non-parametric trend test for the time series $x$, returning the $\tau$ statistic and the $p$-value (`sl`). 
* **`stats::p.adjust(p, method = "BH")`:** Adjusts a vector of $p$-values using the Benjamini-Hochberg method.
* **`base::rle(x)`:** Computes the lengths and values of runs of equal values in the vector $x$, used for calculating consecutive heat days.
* **`dplyr::lag()` and `dplyr::lead()`:** Used for creating rolling windows ($\pm 15$ days) to calculate the 98th percentile for heat day thresholds.