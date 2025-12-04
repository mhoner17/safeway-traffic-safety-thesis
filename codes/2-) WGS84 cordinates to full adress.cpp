import pandas as pd
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
from tqdm import tqdm
import time

#  Read the Excel file with already converted coordinates
df = pd.read_excel("donusturulmus_kaza_koordinatlari.xlsx")

#  Set up the Nominatim geocoder (note the timeout here)
geolocator = Nominatim(user_agent="my_lithuania_reverse_geocoder_2025", timeout=10)

#  Wrap the reverse geocoder with a RateLimiter (no timeout here)
geocode = RateLimiter(
    geolocator.reverse,
    min_delay_seconds=1.1,  # Respect OpenStreetMap rate limit
    max_retries=3,
    error_wait_seconds=5,
    swallow_exceptions=True
)

#  Create the address column if it does not exist yet
if "address" not in df.columns:
    df["address"] = None

#  Prepare tqdm to show a nice progress bar in pandas-style
tqdm.pandas(desc="Querying addresses")

#  Iterate through all rows and fetch reverse geocoded addresses
for idx, row in tqdm(df.iterrows(), total=len(df), desc="Reverse geocoding"):
    if pd.isna(row["address"]):
        try:
            # Call Nominatim with latitude/longitude and request English results
            location = geocode((row["Latitude"], row["Longitude"]), language="en")
            df.at[idx, "address"] = location.address if location else None
        except Exception as e:
            # If something goes wrong, log the error and pause briefly
            print(f"❌ Error (row {idx}): {e}")
            time.sleep(10)  # Back off a bit if too many errors occur

#  Save the updated DataFrame with addresses to a new Excel file
output_path = "kaza_adresli.xlsx"
df.to_excel(output_path, index=False)

print(f"✅ Done. Data with addresses has been saved to:\n{output_path}")
