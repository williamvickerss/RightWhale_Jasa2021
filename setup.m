% Script to download the DCLDE 2013 dataset.
% Upcall, gunshot and no-whale data will then be extracted into seperate
% folders using the labels files provided. All data will be kept within a
% single folder at the current path.

% No-Whale segments are taken equally from upcall and gunshot files with
% segments occuring 5 seconds after a detection.


%% Downloading and extracting the DCLDE 2013 data.
root_folder = 'DCLDE2013_Data';
event_segments_required = 1328;
classes = {'Upcall', 'Gunshot', 'NoWhale'};

root_path = pwd;
root_path = fullfile(root_path, root_folder);

if ~exist(root_folder, 'dir')
    mkdir(root_folder)
    cd (root_folder)
    
    segments_folder = 'Stellwagen';
    if ~exist(segments_folder, 'dir')
        mkdir(segments_folder)
        cd (segments_folder)
            for i = 1:length(classes)
                mkdir(classes{i})
            end
        cd ..
    end

    data_urls = {'https://soi.st-andrews.ac.uk/static/soi/dclde2013/data/NOPPWavSet1.zip'; ...
        'https://soi.st-andrews.ac.uk/static/soi/dclde2013/data/NOPPLogsSet1Repaired.zip'; ...
        'https://soi.st-andrews.ac.uk/static/soi/dclde2013/data/GunshotsWavSet1.zip'; ...
        'https://soi.st-andrews.ac.uk/static/soi/dclde2013/data/GunshotsLogsSet1Repaired.zip'};
    save_data_folders = {classes{1}; [classes{1}, '_logs']; classes{2}; [classes{2}, '_logs']};

    for i = 1:length(data_urls)
        url = data_urls{i};
        save_folder_name = save_data_folders{i};
        zip_folder_name = strcat(save_folder_name, save_extension);
        folder_split = split(save_folder_name, '_');

        urlwrite(url, zip_folder_name);
        if(length(folder_split) > 1)
            unzip(zip_folder_name, save_data_folders{i-1});
        else
            unzip(zip_folder_name, save_folder_name);
        end
        delete (zip_folder_name);
    end
end

%% Combine 15 minute audio files into 24 hour files to match the labels.
folders_to_combine = {save_data_folders{1}; save_data_folders{3}};

for i = 1:length(folders_to_combine)
    cd (folders_to_combine{i})
    
    folders_list = dir();
    folders_list(ismember({folders_list.name}, {'.', '..'})) = [];
    dirFlags = [folders_list.isdir];
    folders_list = folders_list(dirFlags);
    data_folder_names = {folders_list.name};
    if (length(data_folder_names) < 1)
        continue
    end
    label_files = dir('*.mat');
    label_file_names = {label_files.name};
    
    for j = 1:length(label_file_names)
        label_name = label_file_names{j};
        label_name = split(label_name, '.mat');
        label_name = label_name{1};
        label_date = split(label_name, '_');
        label_date = label_date{2};
        k = strfind(data_folder_names, label_date);
        matching_index = find(~cellfun(@isempty,k));
        matching_folder_name = data_folder_names{matching_index};

        cd (matching_folder_name)
        
        all_data = [];
        file_names = dir('*.wav');
        file_names = {file_names.name};
        save_name = strcat(label_name, '.wav');

        for l = 1:length(file_names)
            [x, fs] = audioread(file_names{l});
            all_data = [all_data; x];
        end
        cd ..
        audiowrite(save_name, all_data, fs);
        rmdir (matching_folder_name, 's')
    end
    cd ..
end

%% Extracting the labeled segments and saving them into seperate folder
% No-Whale segments will be taken equally from the two folders and 5
% seconds after a detection event.

for i = 1:length(folders_to_combine)
    current_folder = folders_to_combine{i};
    cd (current_folder)
    
    no_whale_segments_required = event_segments_required/2;
    event_files = dir('*.mat');
    event_files = {event_files.name};
    segment_length_in_secs = 2;
    padding_in_secs = 5;

    event_folder = fullfile(root_path, segments_folder, current_folder);
    no_whale_event_folder = fullfile(root_path, segments_folder, classes{3});

    all_detection_events = {};
    num_detection_events = 0;
    all_no_whale_events = {};
    num_no_whale_events = 0;

    for j = 1:length(event_files)
        % Read the .mat file and set up the events into a struct
        load(event_files{j});
        current_set_name = strsplit(event_files{j}, '.');
        current_set_name = current_set_name{1};
        struct_name = strcat('Log_', current_set_name);
        audio_name = strcat(current_set_name, '.wav');
        eval(['events = ',struct_name,'.event;']);

        collection_name = strsplit(current_set_name, '_');
        day = collection_name{2};
        type = collection_name{4};
        day_name = strcat(current_folder, '-', day);
        % Read the audio associated for processing
        [audio, fs] = audioread(audio_name);

        required_segment_length = segment_length_in_secs * fs;
        required_gap = fs * padding_in_secs;
        minimum_gap_between_events = required_gap * 2 + required_segment_length;

        % Pull events from label file, convert to a matrix and sort into
        % ascending order
        event_timings = {events.time};
        event_timings = event_timings';
        event_timings = cell2mat(event_timings);
        event_timings = sortrows(event_timings);

        % Loop the events
        for k = 1:length(event_timings)
            num_detection_events = num_detection_events + 1;
            % File names for detection events and no-whale events.
            event_segment_save_name = strcat(day_name, '-event-', num2str(k), '.wav');
            no_whale_segment_save_name = strcat('NoWhale-', day_name, '-event-', num2str(k), '.wav');

            % Get the detection event time
            time = event_timings(k, :);

            % Convert time to samples for extraction from audio
            samples = time * fs;
            samples = ceil(samples);
            % Update start and end samples
            start_sample = samples(1, 1);
            end_sample = samples(1, 2);
            % Either lengthen or shorten a segment to fit into the standard
            % block length
            [start_sample, end_sample] = fit_segment(start_sample, end_sample, ...
                required_segment_length);

            % Save the detection event
            event_segment = audio(start_sample : end_sample - 1);
            save_path = fullfile(event_folder, event_segment_save_name);
            all_detection_events{num_detection_events, 1} = save_path;
            all_detection_events{num_detection_events, 2} = event_segment;
            all_detection_events{num_detection_events, 3} = num_detection_events;
            % audiowrite(save_path, event_segment, fs);

            % Calulate if a no-whale event is possible based on user requested gap
            % If gap between the end of this event and start of next is at
            % least padding * 2 + segment_length then proceed
            if (k == length(event_timings))
                continue;
            end
            next_event_time = event_timings(k + 1, :);
            next_event_samples = next_event_time * fs;
            next_event_samples = ceil(next_event_samples);
            next_event_start_sample = next_event_samples(1, 1);
            next_event_end_sample = next_event_samples(1, 2);
            [next_event_start_sample, next_event_end_sample] = ...
                fit_segment(next_event_start_sample, next_event_end_sample, ...
                required_segment_length);

            event_gap = next_event_start_sample - end_sample;

            if (event_gap < minimum_gap_between_events)
                continue;
            end

            % Create the start and end samples for the no-whale segment
            no_whale_start_sample = end_sample + required_gap;
            no_whale_end_sample = no_whale_start_sample + required_segment_length;

            no_whale_segment = audio(no_whale_start_sample : no_whale_end_sample - 1);
            save_path = fullfile(no_whale_event_folder, no_whale_segment_save_name);
            num_no_whale_events = num_no_whale_events + 1;
            all_no_whale_events{num_no_whale_events, 1} = save_path;
            all_no_whale_events{num_no_whale_events, 2} = no_whale_segment;
            all_no_whale_events{num_no_whale_events, 3} = num_detection_events;

            %audiowrite(save_path, no_whale_segment, fs);

        end
    end

    detection_events_saved = save_spaced_files(all_detection_events, fs, event_segments_required);
    detection_positions = cell2mat(detection_events_saved(:, 3));

    to_keep = cell2mat(all_no_whale_events(:, 3));
    no_whale_events_to_save = {};
    counter = 1;
    for k = 1:length(to_keep)
        value = to_keep(k);
        if (ismember(value, detection_positions))
            no_whale_events_to_save(counter, :) = all_no_whale_events(k, :);
            counter = counter + 1;
        end
    end

    no_whale_events_saved = save_spaced_files(no_whale_events_to_save, fs, no_whale_segments_required);

    cd ..
end

cd ..

%% Function to pad a segment equally to fill a 2 second block
function [start_sample, end_sample] = fit_segment(start_sample, end_sample, segment_length_required)
    
    % is segment too long or too short
    duration = end_sample - start_sample;
    
    if (duration > segment_length_required)
        extra_samples = duration - segment_length_required;
        start_remove = ceil(extra_samples/2);
        end_remove = floor(extra_samples/2);

        start_sample = start_sample + start_remove;
        end_sample = end_sample - end_remove;
        
    elseif (duration < segment_length_required)
        extra_samples = segment_length_required - duration;
        start_remove = ceil(extra_samples/2);
        end_remove = floor(extra_samples/2);

        start_sample = start_sample - start_remove;
        end_sample = end_sample + end_remove;
    end

    return

end

%% Function to calculate how often to take no-whale segments so that they
% are equally spaced.
function [take, skip] = spaced_files(n, p)
    if (n == p)
        take = 1;
        skip = 0;
       
    elseif (n < p)
        msg = ['You cannot take ', num2str(p), ' from ', num2str(n), ' values.'];
        error(msg);
   
    else    
        ratio = n/p;
        if (ratio < 2)
            ratio = ratio - 1;
            if (ratio < 0.1)
               ratio = 0.1; 
            else
                new_ratio = floor((ratio * 10));
                ratio = new_ratio / 10;
            end

            [skip, take] = rat(ratio);
        else
            take = 1;
            skip = floor(ratio) - 1;
        end
    end
    
    return
end


%% Function to save equally spaced files
function saved_rows = save_spaced_files(segments, fs, segments_required)

    [take, skip] = spaced_files(length(segments), segments_required);
    saved_rows = {};
    jump = take + skip;
    total_saved = 0;
    for k = 1:jump:length(segments)
        count = k;
        for l = 1:take
            [y, d] = highpass(segments{count, 2}, 20, fs);
            audiowrite(segments{count, 1}, y, fs);
            total_saved = total_saved + 1;
            saved_rows(total_saved, :) = segments(count, :);
            if (total_saved == segments_required)
                return
            end
            count = count + 1;
        end
    end
end
 

