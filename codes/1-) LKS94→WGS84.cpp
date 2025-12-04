import pandas as pd
from pyproj import Transformer
from tqdm import tqdm

# Path to the original Excel file with accident coordinates
file_path = r"C:\Users\mhone\Desktop\dosyaCordinat\2020-2024 accident.xlsx"

# Read the Excel file (use the correct sheet name)
df = pd.read_excel(file_path, sheet_name="2020-2024")

# Remove any extra spaces from column names just in case
df.columns = df.columns.str.strip()

# Drop rows where either Ilguma or Platuma is missing
df_clean = df.dropna(subset=['Ilguma', 'Platuma']).copy()

# Convert coordinates to float:
# - First, make sure they are strings
# - Replace comma with dot as decimal separator
# - Then convert to float type
df_clean['Ilguma'] = (
    df_clean['Ilguma']
    .astype(str)
    .str.replace(',', '.')
    .astype(float)
)

df_clean['Platuma'] = (
    df_clean['Platuma']
    .astype(str)
    .str.replace(',', '.')
    .astype(float)
)

# Define the coordinate transformer (from EPSG:3346 to EPSG:4326 / WGS84)
transformer = Transformer.from_crs("EPSG:3346", "EPSG:4326", always_xy=True)

# Lists to store transformed longitude and latitude values
longitudes = []
latitudes = []

# Loop through all coordinate pairs and transform them
# tqdm is used here to show a progress bar while processing
for x, y in tqdm(
    zip(df_clean['Platuma'], df_clean['Ilguma']),
    total=len(df_clean),
    desc="Converting coordinates"
):
    lon, lat = transformer.transform(x, y)
    longitudes.append(lon)
    latitudes.append(lat)

# Add the new longitude/latitude columns to the cleaned DataFrame
df_clean['Longitude'] = longitudes
df_clean['Latitude'] = latitudes

# Define the output path for the new Excel file
output_path = r"C:\Users\mhone\Desktop\donusturulmus_kaza_koordinatlari.xlsx"

# Save the transformed data to a new Excel file (without the index)
df_clean.to_excel(output_path, index=False)

# Simple confirmation message in the console
print(f"Coordinates were successfully converted and saved to:\n{output_path}")
