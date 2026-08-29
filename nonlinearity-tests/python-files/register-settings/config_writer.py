# This file converts the Infineon generated register configuration file into readable 8 digit hex for ROM initialization. 

input_filename = "python-files/register-settings/registers.txt"
output_filename = "t120us_15.mem"

word_count = 0
with open(input_filename, "r") as infile, open(output_filename, "w") as outfile:
    for line in infile:
        if line.strip() == "":
            continue

        parts = line.split()

        address = int(parts[1], 16)
        data = int(parts[2], 16)

        instruction = (address << 25) | (1 << 24) | data

        outfile.write(f"{instruction:08x}\n")

        word_count += 1

print(f"Number of words: {word_count}")