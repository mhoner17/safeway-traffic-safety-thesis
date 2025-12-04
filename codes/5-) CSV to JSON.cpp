import pandas as pd
import json
from pathlib import Path


def csv_to_json(csv_path: str, json_path: str, sep: str = ",") -> None:

    csv_file = Path(csv_path)
    json_file = Path(json_path)

    if not csv_file.exists():
        raise FileNotFoundError(f"Input CSV file not found: {csv_file}")


    df = pd.read_csv(csv_file, sep=sep, encoding="utf-8-sig")


    numeric_columns = [
        "Z_score",
        "Total_Cluster_Number_DBSCAN",
        "Total_Accidents",
    ]
    for col in numeric_columns:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")


    records = df.to_dict(orient="records")


    with json_file.open("w", encoding="utf-8") as f:
        json.dump(
            records,
            f,
            ensure_ascii=False,
            indent=4
        )

    print(f"JSON file successfully created: {json_file.resolve()}")


if __name__ == "__main__":

    input_csv = "k_k_v_accidents_data_lithuanian.csv"
    output_json = "k_k_v_accidents_data_lithuanian.json"

    csv_to_json(input_csv, output_json, sep=",")
