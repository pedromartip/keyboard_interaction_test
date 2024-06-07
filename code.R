# Reminder: before running this script in RStudio, set the working directory
# to the location of the source file and data file:
#
#    Session --> Set Working Directory --> To Source File Location

# fresh start
cat("\f")                       # clear console
rm(list = ls(all.names = TRUE)) # clear environment

# Install necessary libraries if not installed yet
necessary_packages <- c("plyr", "dplyr", "rstatix", "ggplot2", "gt", "webshot", "webshot2", "DescTools")
for (pkg in necessary_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
}

# Import libraries
library(plyr)
library(dplyr)
library(rstatix)
library(ggplot2)
library(gt)
library(webshot)
library(webshot2)
library(DescTools)

# Obtain current directory path
root_dir <- getwd()

# Found all sd2 files
sd2_files <- list.files(path = root_dir, pattern = "\\.sd2$", recursive = TRUE, full.names = TRUE)

# Create a list to store all the data
data_list <- list() # Here will go the .sd2 files data

# Read each .sd2 file and adding the data to the data_list
for (file in sd2_files) {
  data <- read.csv(file)
  #print(data)
  data_list[[length(data_list) + 1]] <- data
}

# Merge all the files in the same data set
combined_data <- do.call(rbind.fill, data_list)

# Show data set
print(combined_data)


# Filtered the variables that we will use: Participant, Condition, Keyboard and Speed_.wpm
filtered_data <- combined_data %>% select(Participant, Condition, Keyboard, Speed_.wpm.)
print(filtered_data)


# Add Trial column to the data set (Why?)
filtered_data <- filtered_data %>%
  mutate(
    Trial = rep(paste0("T", 1:5), length.out = n())
  )

# Add column for levels of within-subjects factor, layout
n <- 4*30 # Number of participants for each group: 4 participants for 30 trials each one
filtered_data$Group = rep(c("G1", "G2", "G3"), each=n)

# Show data set
print(filtered_data)

# Ordering the data by Condition, Keyboard and Trial
ordered_data <- filtered_data %>%
  arrange(Condition, Keyboard, Trial) %>%
  rename(Entry_Speed = Speed_.wpm.)

# Transform the categorical information to factors
ordered_data$Keyboard <- factor(ordered_data$Keyboard)
ordered_data$Trial <- factor(ordered_data$Trial)
ordered_data$Participant <- factor(ordered_data$Participant)
ordered_data$Group <- factor(ordered_data$Group)
ordered_data$Condition <- factor(ordered_data$Condition)

#Print for check data structure
print(str(ordered_data))

# Visualize the data with a boxplot for visualise the destribution of 
# the entry_speed for each keyboard and group, divided by the Trial
ggplot(ordered_data, aes(x = Keyboard, y = Entry_Speed, color = Group)) +
  geom_boxplot() +
  facet_wrap(~ Trial)

# Check for outliers for each combination of group, keyboard and trial
outliers <- ordered_data %>%
  group_by(Group, Keyboard, Trial) %>%
  identify_outliers(Entry_Speed)

print(outliers)

extreme_outliers <- outliers %>% filter(is.extreme == TRUE)

# Remove extreme outliers
clean_data <- ordered_data %>% 
  anti_join(extreme_outliers, by = c("Participant", "Group", "Keyboard", "Trial", "Condition"))
print(clean_data)


# outliers_gt <- gt(outliers)#Crear una tabla gt para los outliers
# gtsave(outliers_gt, "outliers_table.png") # Guardar la tabla como una imagen

# Normality assumption with Shapiro-Wilk
normality_test <- ordered_data %>%
  group_by(Group, Keyboard, Trial) %>%
  shapiro_test(Entry_Speed)

print(normality_test)
# normality_test_gt <- gt(normality_test)
# gtsave(normality_test_gt, "normality_test.png") 


# Homogeneity of variances assumption between groups using the Levene test
levene_test <- ordered_data %>%
  levene_test(Entry_Speed ~ Group * Keyboard * Trial)

print(levene_test)
# levene_test_gt <- gt(levene_test)
# gtsave(levene_test_gt, "levene_test.png") 

# ANOVA test to evaluate the effect of the group, keyboard and trial combination on the entry_speed
res.aov = anova_test(
  data = ordered_data,
  formula = Entry_Speed ~ Group*Keyboard*Trial*Condition + Error(Participant/(Keyboard*Trial*Condition)),
  detailed=TRUE
)

# Get ANOVA table, print in a shorter way the same as the code below
anova_table <- get_anova_table(res.aov)
print(anova_table)


# Analyze the main effect of each factor and also the interaction effect
aov <- aov(Entry_Speed ~ Group*Keyboard*Trial*Condition + Error(Participant/(Keyboard*Trial*Condition)), ordered_data)
summary(aov) 

# Analyze only the main effect of each factor
aov <- aov(Entry_Speed ~ Group+Keyboard+Trial+Condition + Error(Participant/(Keyboard+Trial+Condition)), ordered_data)
summary(aov) 


# POST HOC COMPARISONS
# Compared the keyboard layout first
model = aov(Entry_Speed~Keyboard, data=ordered_data)
summary(model)
post_hoc_scheffe <- PostHocTest(model, which=NULL, "scheffe") 
print(post_hoc_scheffe)#Print the results of the Scheffé test

# Compared the trial results
model = aov(Entry_Speed~Trial, data=ordered_data)
summary(model)
post_hoc_scheffe <- PostHocTest(model, which=NULL, "scheffe") 
print(post_hoc_scheffe)#Print the results of the Scheffé test
