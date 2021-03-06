source("code/00_pkg_functions.R")

# get plant data ---------------------------------------------------------------
# plantDiv dpid
plant_code <- 'DP1.10058.001'

# site_id = c("OSBS", "ABBY")

all_tabs <- neonUtilities::loadByProduct(
  dpID = plant_code,
  # site = site_id, 
  check.size = TRUE)
str(all_tabs)

# download field data for all dates for two neon sites -- much more manageable 
div_1m2_pla <- filter(all_tabs$div_1m2Data, divDataType == 'plantSpecies')  
# Remove 1m2 data with targetTaxaPresent = N
div_1m2_pla <- filter(div_1m2_pla, targetTaxaPresent != 'N')

div_1m2_oVar <- filter(all_tabs$div_1m2Data, divDataType == 'otherVariables') 
table(div_1m2_oVar$otherVariables)

div_10_100_m2 <- all_tabs$div_10m2Data100m2Data

# Remove rows without plotID, subplotID, boutNumber, endDate, and/or taxonID 
div_1m2_pla <- drop_na(div_1m2_pla, plotID, subplotID, boutNumber, endDate, taxonID)
div_10_100_m2 <- drop_na(div_10_100_m2, plotID, subplotID, boutNumber, endDate, taxonID)

# Remove duplicate taxa between nested subplots (each taxon should be represented once for the bout/plotID/year). 
# 1) If a taxon/date/bout/plot combo is present in 1m2 data, remove from 10/100
div_1m2_pla <- mutate(div_1m2_pla, primaryKey = paste(plotID, boutNumber, substr(endDate, 1, 4), 
                                                      taxonID, subplotID, sep = '_'),
                      key2 = gsub("[.][0-9]$", "", primaryKey),
                      key3 = gsub("[.][0-9]$", "", key2))
div_10_100_m2 <- mutate(div_10_100_m2, primaryKey = paste(plotID, boutNumber, substr(endDate, 1, 4), 
                                                          taxonID, subplotID, sep = '_'),
                        key2 = gsub("[.][0-9]{2}$", "", primaryKey),
                        key3 = gsub("[.][0-9]$", "", key2))
# additional species in 10m2 and 100m2 but not in 1m2
div_10_100_m2_2 <- filter(div_10_100_m2, !key2 %in% unique(div_1m2_pla$key2)) 
# species in 10m2 only
div_10_100_m2_3 <- filter(div_10_100_m2_2, key2 != key3)
# species in 100m2 only (remove species already in 1m2 or 10m2)
div_10_100_m2_4 <- filter(div_10_100_m2_2, key2 == key3,
                          !key3 %in% unique(c(div_1m2_pla$key3, div_10_100_m2_3$key3)))
div_10_100_m2_5 = bind_rows(mutate(div_10_100_m2_3, sample_area_m2 = 10), 
                            mutate(div_10_100_m2_4, sample_area_m2 = 100))

# stack data
div_plt = bind_rows(
  select(div_1m2_pla, uid, domainID, namedLocation, siteID, decimalLatitude, decimalLongitude,
         plotID, subplotID, boutNumber, endDate, taxonID, scientificName, taxonRank, 
         family, nativeStatusCode, percentCover, heightPlantOver300cm, heightPlantSpecies) %>% 
    mutate(sample_area_m2 = 1), # 1m2
  select(div_10_100_m2_5, uid, domainID, namedLocation, siteID, decimalLatitude, decimalLongitude,
         plotID, subplotID, boutNumber, endDate, taxonID, scientificName, taxonRank, 
         family, nativeStatusCode, sample_area_m2)
) %>% 
  mutate(subplot_id = str_sub(subplotID, 1, 2),
         subsubplot_id = str_sub(subplotID, 4, 4),
         yr = lubridate::year(lubridate::ymd(endDate))) %>% 
  unique() %>% 
  as_tibble()

saveRDS(div_plt, "data/div_plants.rds")

table(div_plt$siteID)
n_distinct(div_plt$siteID) # 47 sites
n_distinct(div_plt$taxonID) # 5950 species
# clean species names??
table(div_plt$taxonRank)
