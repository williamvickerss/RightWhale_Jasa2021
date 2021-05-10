import numpy as np
from scipy.io import wavfile
from pathlib import Path
import os
import argparse
import natsort.natsort as ns
import random
from shutil import copyfile
import csv
import math


parser = argparse.ArgumentParser()
parser.add_argument('-w', action='store_true', help='White noise partitions will be created at SNRs of +5, 0, -5, -10.')
parser.add_argument('-m', action='store_true', help='Only white noise partitions will be created.')

args = parser.parse_args()
produce_white = args.w
produce_standard = not args.m

stage = 0
root_folder_name = 'DCLDE2013_Data'
dataset_name = 'Stellwagen'
events_folder_name = 'Events'
class_names = ['NoWhale', 'Gunshot', 'Upcall']

noise_levels = [5, 0, -5, -10]
noise_level_folder_names = ['White ' + str(f) + 'dB' for f in noise_levels]
split = (2784, 600, 600)


def main():
    is_data_present()

    if produce_standard:
        begin_partition(dataset_name)
    if produce_white:
        for i, j in zip(noise_levels, noise_level_folder_names):
            begin_partition(dataset_name, i, j)

    print('Partitions successfully produced. End.')


def begin_partition(folder_name, noise_level=None, noise_name=None):
    os.chdir(root_folder_name)

    if noise_name is not None:
        folder_name = ' '.join((folder_name, noise_name))

    if not os.path.exists(folder_name):
        print(return_stage() + '.) Creating ' + folder_name)
        all_paths = os.path.join(folder_name,
                                 'test_data', '..',
                                 'test_labels', '..',
                                 'train_data', '..',
                                 'train_labels', '..',
                                 'validation_data', '..',
                                 'validation_labels')

        os.makedirs(all_paths)

    if noise_name is not None:
        finish_partition(events_folder_name, folder_name, noise_level)
    else:
        finish_partition(events_folder_name, folder_name)

    os.chdir('..')


def finish_partition(read_folder, save_folder, target_snr=None):
    add_noise = True if target_snr is not None else False
    white_noise_seed = 1
    print(return_stage() + '.) Splitting the data into train, validation and test')
    class_folders = [f for f in os.listdir(read_folder) if not f.startswith('.')]
    num_classes = len(class_folders)
    split_per_class = [int(i / num_classes) for i in split]

    train_counter = 1
    test_counter = 1
    val_counter = 1

    for class_idx, class_folder in enumerate(class_folders):

        file_names_path = os.path.join(read_folder, class_folder)
        file_names = os.listdir(file_names_path)
        file_names = ns.natsorted(file_names)

        random.seed(1)
        random.shuffle(file_names)

        train_data = file_names[:split_per_class[0]]
        validation_data = file_names[split_per_class[0]:split_per_class[0] + split_per_class[1]]
        test_data = file_names[split_per_class[0] + split_per_class[1]:]

        if add_noise:
            train_counter, white_noise_seed = move_audio(train_data, 'train',
                                                         train_counter, file_names_path,
                                                         save_folder, class_idx, white_noise_seed, target_snr)
            val_counter, white_noise_seed = move_audio(validation_data, 'validation',
                                                       val_counter, file_names_path,
                                                       save_folder, class_idx, white_noise_seed, target_snr)
            test_counter, white_noise_seed = move_audio(test_data, 'test',
                                                        test_counter, file_names_path,
                                                        save_folder, class_idx, white_noise_seed, target_snr)
        else:
            train_counter, _ = move_audio(train_data, 'train', train_counter, file_names_path, save_folder,
                                          class_idx)
            val_counter, _ = move_audio(validation_data, 'validation', val_counter, file_names_path, save_folder,
                                        class_idx)
            test_counter, _ = move_audio(test_data, 'test', test_counter, file_names_path, save_folder,
                                         class_idx)


def move_audio(data, main_name, counter, file_names_path, save_folder, class_idx, white_noise_seed=None,
               target_snr=None):
    data_name = main_name + '_data'
    label_name = main_name + '_labels'

    for file_name in data:
        full_current_path = os.path.join(file_names_path, file_name)
        wav_save_name = main_name + str(counter) + '-' + file_name
        counter += 1
        csv_save_name = wav_save_name.split('.')[0] + '.csv'
        full_wav_save_path = os.path.join(save_folder, data_name, wav_save_name)
        full_csv_save_path = os.path.join(save_folder, label_name, csv_save_name)

        if target_snr is not None:
            add_noise_to_audio(full_current_path, full_wav_save_path, white_noise_seed, target_snr)
            white_noise_seed += 1
        else:
            copyfile(full_current_path, full_wav_save_path)
        with open(full_csv_save_path, 'w', newline='') as file:
            writer = csv.writer(file)
            writer.writerow([class_idx])

    return counter, white_noise_seed


def add_noise_to_audio(full_current_path, full_wav_save_path, white_noise_seed, target_snr):
    fs, audio = wavfile.read(full_current_path)
    audio = audio.astype(np.float)

    white_noise = generate_white_noise_with_seed(len(audio), white_noise_seed)

    signal_p = calculate_audio_power(audio)
    noise_p = calculate_audio_power(white_noise)

    if full_current_path.split('-')[0].endswith('NoWhale'):
        signal_p = find_matching_event(full_current_path)

    to_the_power = -target_snr / 10
    multiplier = 10 ** to_the_power
    alpha = math.sqrt(((signal_p / noise_p) * multiplier))

    correct_snr_noise = white_noise * alpha
    noisy_audio = audio + correct_snr_noise

    wavfile.write(full_wav_save_path, fs, noisy_audio)


def find_matching_event(current_wav_path):
    paired_file_name = '-'.join(current_wav_path.split('-')[2:])
    folders_to_search = [f for f in os.listdir(events_folder_name) if not f.startswith('.')]
    for search_folder in folders_to_search:
        file_search_folder = os.listdir(os.path.join(events_folder_name, search_folder))
        matches = [x for x in file_search_folder if x.endswith(paired_file_name)]
        for m in matches:
            if 'NoWhale' not in m:
                paired_audio_path = os.path.join(events_folder_name, search_folder, m)

    fs, paired_data = wavfile.read(paired_audio_path)
    paired_data = paired_data.astype(np.float)
    return calculate_audio_power(paired_data)


def is_data_present():
    print('\n\n')
    print(return_stage() + '.) Checking the data is present.')
    data_present = os.path.exists(root_folder_name)

    if data_present:
        print('Data found. Continuing...')
        return
    else:
        print('The ', root_folder_name,
              ' folder cannot be found at this path. Please run \'setup.m\' before continuing!')
        print('Exiting')
        quit()


def return_stage():
    global stage
    stage += 1
    return str(stage)


def generate_white_noise_with_seed(length, seed):
    random.seed(seed)
    white_noise = [random.gauss(0.0, 1.0) for i in range(length)]
    white_noise = np.asarray(white_noise)
    white_noise = white_noise.astype(np.float)
    return white_noise


def calculate_audio_power(audio):
    audio_power = sum([(i ** 2) for i in audio]) / len(audio)
    return audio_power


if __name__ == "__main__":
    main()
