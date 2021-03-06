%
% Framework for developping attacks in Matlab under Windows
% for the DPA contest V4, AES256 RSM implementation
%
% Requires the wrapper tool for Windows
%
% Version 1, 29/07/2013
%
% Guillaume Duc <guillaume.duc@telecom-paristech.fr>
%

% Number of the attacked subkey
% TODO: adapt it
hanmingweight = [
    0 1 1 2 1 2 2 3 1 2 2 3 2 3 3 4 ...
    1 2 2 3 2 3 3 4 2 3 3 4 3 4 4 5 ...
    1 2 2 3 2 3 3 4 2 3 3 4 3 4 4 5 ...
    2 3 3 4 3 4 4 5 3 4 4 5 4 5 5 6 ...
    1 2 2 3 2 3 3 4 2 3 3 4 3 4 4 5 ...
    2 3 3 4 3 4 4 5 3 4 4 5 4 5 5 6 ...
    2 3 3 4 3 4 4 5 3 4 4 5 4 5 5 6 ...
    3 4 4 5 4 5 5 6 4 5 5 6 5 6 6 7 ...
    1 2 2 3 2 3 3 4 2 3 3 4 3 4 4 5 ...
    2 3 3 4 3 4 4 5 3 4 4 5 4 5 5 6 ...
    2 3 3 4 3 4 4 5 3 4 4 5 4 5 5 6 ...
    3 4 4 5 4 5 5 6 4 5 5 6 5 6 6 7 ...
    2 3 3 4 3 4 4 5 3 4 4 5 4 5 5 6 ...
    3 4 4 5 4 5 5 6 4 5 5 6 5 6 6 7 ...
    3 4 4 5 4 5 5 6 4 5 5 6 5 6 6 7 ...
    4 5 5 6 5 6 6 7 5 6 6 7 6 7 7 8
    ];
sbox = [
      99,124,119,123,242,107,111,197, 48,  1,103, 43,254,215,171,118, ...
     202,130,201,125,250, 89, 71,240,173,212,162,175,156,164,114,192, ...
     183,253,147, 38, 54, 63,247,204, 52,165,229,241,113,216, 49, 21, ...
       4,199, 35,195, 24,150,  5,154,  7, 18,128,226,235, 39,178,117, ...
       9,131, 44, 26, 27,110, 90,160, 82, 59,214,179, 41,227, 47,132, ...
      83,209,  0,237, 32,252,177, 91,106,203,190, 57, 74, 76, 88,207, ...
     208,239,170,251, 67, 77, 51,133, 69,249,  2,127, 80, 60,159,168, ...
      81,163, 64,143,146,157, 56,245,188,182,218, 33, 16,255,243,210, ...
     205, 12, 19,236, 95,151, 68, 23,196,167,126, 61,100, 93, 25,115, ...
      96,129, 79,220, 34, 42,144,136, 70,238,184, 20,222, 94, 11,219, ...
     224, 50, 58, 10, 73,  6, 36, 92,194,211,172, 98,145,149,228,121, ...
     231,200, 55,109,141,213, 78,169,108, 86,244,234,101,122,174,  8, ...
     186,120, 37, 46, 28,166,180,198,232,221,116, 31, 75,189,139,138, ...
     112, 62,181,102, 72,  3,246, 14, 97, 53, 87,185,134,193, 29,158, ...
     225,248,152, 17,105,217,142,148,155, 30,135,233,206, 85, 40,223, ...
     140,161,137, 13,191,230, 66,104, 65,153, 45, 15,176, 84,187, 22
     ];
idx1= [6755,11097,15439,19779,24121,28462,32805,37145,41488,45829,50171,54511,58854,63195,67537,71877];
idx2= [101580,187079,200738,275730,256964,180851,203605,217265,285533,251641,197378,220131,314103,184202,270408,213891];

attacked_subkey = 0;

ssamples = zeros(1,320);
s2samples = zeros(1,320);
sd = zeros(16,256,20);
intermedia = zeros(16,256);
sintermedia = zeros(16,256);
s2intermedia = zeros(16,256);
r = zeros(16,256);

% FIFO filenames (the last argument when launching the
% wrapper should be 'fifo')

 fifo_in_filename = '\\.\pipe\fifo_from_wrapper';
 fifo_out_filename = '\\.\pipe\fifo_to_wrapper';


% Open the two communication FIFO
% We have to use the Java interface as the native function fopen from
% Matlab is unable to open FIFO!

fifo_in = java.io.FileInputStream(fifo_in_filename);
fifo_out = java.io.FileOutputStream(fifo_out_filename);

% Retrieve the number of traces

num_traces_b = arrayfun(@(x) fifo_in.read(), 1:4);
num_traces = num_traces_b(4) * 2^24 + num_traces_b(3) * 2^16 + num_traces_b(2) * 2^8 + num_traces_b(1);

% Send start of attack string
% attack_wrapper.exe -i 500 -d DPA_contestv4_rsm -x dpav4_rsm_index\dpav4_rsm_index_1000.txt -e v4_RSM fifo

fifo_out.write([10 46 10]);


% Main loop
for iteration = 1:num_traces

    % Read trace
    plaintext = arrayfun(@(x) fifo_in.read(), 1:16);
    ciphertext = arrayfun(@(x) fifo_in.read(), 1:16);
    offset = fifo_in.read();
    samples = arrayfun(@(x) fifo_in.read(), 1:435002);
       
    samples = arrayfun(@(x) typecast(uint8(x),'int8'), samples); % convert to signed bytes
    
    % read power1 and power2
    for i=1:16;
    samplesMulti(i,:) = samples(idx1(mod(i,16)+1):idx1(mod(i,16)+1)+19).*samples(idx2(i):idx2(i)+19);
    end
    samples = [
        samplesMulti(1,:)  samplesMulti(2,:)  samplesMulti(3,:)  samplesMulti(4,:)  ... 
        samplesMulti(5,:)  samplesMulti(6,:)  samplesMulti(7,:)  samplesMulti(8,:)  ...
        samplesMulti(9,:)  samplesMulti(10,:) samplesMulti(11,:) samplesMulti(12,:) ...
        samplesMulti(13,:) samplesMulti(14,:) samplesMulti(15,:) samplesMulti(16,:)
        ];
    % offset
    % compute intermedia
    for guesskey=0:255
        for i=1:16
            tmp = bitxor(plaintext(i),guesskey);
            tmp = bitxor(sbox(tmp+1),plaintext(mod(i,16)+1));
            intermedia(i,guesskey+1) = hanmingweight(tmp+1);
            for j=1:20
                sd(i,guesskey+1,j) = sd(i,guesskey+1,j) + intermedia(i,guesskey+1) * double(samples(j+(i-1)*20));
            end
        end
    end
    sintermedia = sintermedia + intermedia;
    s2intermedia = s2intermedia + intermedia.^2;
    
    ssamples = ssamples + double(samples);
    s2samples = s2samples + double(samples).^2;
       
    tmpr = zeros(1,20);
    for i=1:16
        for guesskey=0:255
            var_intermedia = (s2intermedia(i,guesskey+1) - sintermedia(i,guesskey+1)*sintermedia(i,guesskey+1)/iteration)/iteration;
            if (var_intermedia == 0)
                r(i,guesskey+1) = 0;
            else
                for j=1:20
                    var_samples = (s2samples(j+(i-1)*20) - ssamples(j+(i-1)*20) * ssamples(j+(i-1)*20) / iteration)/iteration;
                    if (var_samples == 0)
                        tmpr(j) = 0;
                    else
                        tmpr(j) = (sd(i,guesskey+1,j) - ssamples(j+(i-1)*20) * sintermedia(i,guesskey+1)/iteration)/iteration / sqrt(var_intermedia) / sqrt(var_samples);
                    end
                end
                r(i,guesskey+1) = max(abs(tmpr));
            end
        end
    end
    
    %bytes = repmat((0:255)', 1, 16);
    [xx bytes] = sort(r','descend');
    bytes = bytes -1;

    % Send result
    fifo_out.write(attacked_subkey);
    fifo_out.write(bytes(:,1));
    fifo_out.write(bytes(:,2));
    fifo_out.write(bytes(:,3));
    fifo_out.write(bytes(:,4));
    fifo_out.write(bytes(:,5));
    fifo_out.write(bytes(:,6));
    fifo_out.write(bytes(:,7));
    fifo_out.write(bytes(:,8));
    fifo_out.write(bytes(:,9));
    fifo_out.write(bytes(:,10));
    fifo_out.write(bytes(:,11));
    fifo_out.write(bytes(:,12));
    fifo_out.write(bytes(:,13));
    fifo_out.write(bytes(:,14));
    fifo_out.write(bytes(:,15));
    fifo_out.write(bytes(:,16));
end
% compute corrlation

% Close the two FIFOs
fifo_in.close();
fifo_out.close();
