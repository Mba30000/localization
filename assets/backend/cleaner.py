import csv

# Specify the input and output CSV files
input_file = 'geo_mappings.csv'  # Your original CSV file
output_file = 'locations.csv'  # New CSV file for the cleaned data

# Open the input and output files
with open(input_file, mode='r', newline='', encoding='utf-8') as infile, \
     open(output_file, mode='w', newline='', encoding='utf-8') as outfile:
    
    # Create CSV reader and writer objects
    csv_reader = csv.reader(infile)
    csv_writer = csv.writer(outfile)
    
    # Process each row
    for row in csv_reader:
        # Remove any empty columns (those that are just commas)
        cleaned_row = [column for column in row if column.strip() != '']
        
        # Write the cleaned row to the new CSV file
        csv_writer.writerow(cleaned_row)

print("CSV cleaned successfully. The cleaned file is saved as:", output_file)
