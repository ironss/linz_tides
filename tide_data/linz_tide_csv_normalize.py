import csv
import datetime
import zoneinfo

tzname = 'Pacific/Auckland'
tz = zoneinfo.ZoneInfo(tzname)

def linz_tide_csv_normalize(port_name, fin):
    reader = csv.reader(fin)
    tides = []
    for row in reader:
        try:
            year = int(row[3])
            month = int(row[2])
            day = int(row[0])
        except:
            continue

        for col in range(4, 12, 2):
            try:
                hour = int(row[col][:2])
                minute = int(row[col][-2:])
                dt = datetime.datetime(year, month, day, hour, minute, tzinfo=tz)
            except ValueError:
                break

            try:
                height_of_tide = float(row[col+1])
            except KeyError:
                break

                
            tide = [port_name, dt, height_of_tide]
            tides.append(tide)
    
    return tides
    

if __name__ == '__main__':
    import argparse
    import sys
    
    parser = argparse.ArgumentParser(
        description="Normalize tides predictions from LINZ CSV files."
    )
    
    parser.add_argument('filename', nargs='+')
    args = parser.parse_args()

    for filename in args.filename:
        port_name = filename[:-9]
    
        with open(filename, encoding='iso8859-1') as fin:
            tides = linz_tide_csv_normalize(port_name, fin)
                
        fout = sys.stdout
        writer = csv.writer(fout)
        for tide in tides:
            writer.writerow(tide)    

