
% Usage:
% motiondetection(): Use webcam as a source
% motion_detection('video.mp4'): Load and buffer a video file as a source


function varargout = motion_detector_final(varargin)

% GUI functionalities:

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @main, ...
                   'gui_OutputFcn',  @gui_OutputFcn, ...i
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end


% Main algorithm:

function main(hObject, ~, handles, varargin)
clc;

% Choose default command line output for GUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% Source selection
if isempty(varargin)
    camera = true;
elseif length(varargin) == 1
    camera = false;
else
    error('motion_detector: Too many input arguments!');
end


% Initialization
if camera
    % Initialize webcam source
    source = webcam;
    framecount = 0;
    resolution = strsplit(source.Resolution, 'x');
    width = str2double(cell2mat(resolution(1)));
    height = str2double(cell2mat(resolution(2)));
    
     % Initialize frame buffer
    fBuf(1:2) = struct('RGB', zeros(height, width, 3, 'uint8'));
    
else
    % Initialize video source
    disp('Configuring video source...');
    source = VideoReader(varargin{1});
    width = source.Width;
    height = source.Height;
    
    % Initialize the frame buffer
    framecount = source.NumberOfFrames; 
    fBuf(1:framecount) = struct('RGB', zeros(height, width, 3, 'uint8'));
    
    % Fill the frame buffer
    source = VideoReader(varargin{1});
    for i = 1:framecount
        clc;
        disp(['Buffering...' num2str(round(i/framecount * 100)) ' %']); 
        fBuf(i).RGB = readFrame(source);
    end
    
end

% Settings
axes(handles.axes1);    % Setting active axes
imshow(fBuf(1).RGB);    % Initialize axes
dBuf_length = -1;       % Preset
fBuf_pos = 2;           % Preset

% Main loop:

running = true;

change = 1;
while running
    if change == 1;
        since_change = tic;
    end
    
    % Read GUI slider values:
    threshold = handles.slider_threshold.Value;
    sigma = handles.slider_sigma.Value;
    buffer_length = round(handles.slider_buffer.Value);
    
    % Update GUI slider text fields:
    set(handles.text_threshold, 'String', num2str(threshold));
    set(handles.text_sigma, 'String', num2str(sigma));
    set(handles.text_buffer, 'String', num2str(buffer_length));
    
    % Determine if difference buffer needs reallocation:
    if buffer_length ~= dBuf_length
        dBuf_length = buffer_length;
        dBuf_fields = dBuf_length * 3;
        dBuf = uint8(zeros(height, width, dBuf_fields));
        dBuf_pos = 1;
    end
    
    % Calculate a difference image to difference buffer:
    if camera
        fBuf(fBuf_pos).RGB = source.snapshot;   % Reads a image from camera
        dBuf(:,:,dBuf_pos:dBuf_pos+2) = fBuf(mod(fBuf_pos,2)+1).RGB - fBuf(mod(fBuf_pos,3)).RGB;
    else
        dBuf(:,:,dBuf_pos:dBuf_pos+2) = fBuf(fBuf_pos-1).RGB - fBuf(fBuf_pos).RGB;
    end
    
    % Calculate a sum of the current difference buffer
    diffsum(:,:,1) = sum( dBuf(:,:,1:3:dBuf_fields), 3 , 'native');
    diffsum(:,:,2) = sum( dBuf(:,:,2:3:dBuf_fields), 3 , 'native');
    diffsum(:,:,3) = sum( dBuf(:,:,3:3:dBuf_fields), 3 , 'native');
    
    % Convert tograyscale and apply blur, then convert to logical bw
    bw = im2bw(imgaussfilt(rgb2gray(diffsum), sigma), threshold);
    
   
    % Show original video frame
    
    if change == 0 && ~isempty(find(bw, 1))
        change = 1;
    end
   
    if change == 1
        if camera
            set(findobj(handles.axes1.Children,'Type','Image'),'CData',fBuf(fBuf_pos).RGB);
        else
            set(findobj(handles.axes1.Children,'Type','Image'),'CData',fBuf(fBuf_pos-dBuf_length).RGB);
        end

        % Find and outline differences
        delete(findobj(gca,'Type','Line'));
        hold on;
        [B,~,N] = bwboundaries(bw);
        for k = 1 : N
            plot(B{k}(:,2), B{k}(:,1), 'r', 'LineWidth', 2);
        end
        pause(0.01); hold off;
        if isempty(find(bw, 1))
            change = 0;
        end
    end
            
    % Cycle frame buffer:
    fBuf_pos = fBuf_pos + 1;
    if fBuf_pos > length(fBuf)
        fBuf_pos = 1;
    end
    
    % Cycle difference buffer:
    dBuf_pos = dBuf_pos + 3;
    if dBuf_pos > dBuf_fields
        dBuf_pos = 1;
    end
    
    % Determine if loop should be terminated
    if ~isvalid(handles.figure1) || fBuf_pos == framecount
        running = false;
        close all;
    end
    
    clc;
    if change == 1
        disp(['FPS: ' sprintf('%2.f', round((toc(since_change))^-1)) ' | ' 'Time since last detected movement: 0.000 seconds.']);
    else
        disp(['FPS:  0' ' | ' 'Time since last detected movement: ' sprintf('%.3f', (toc(since_change))) ' seconds.']);
    end
end



% GUI stuff:

function varargout = gui_OutputFcn(hObject, eventdata, handles)
if ~isempty(handles)
    varargout{1} = handles.output;
end

function slider_threshold_Callback(hObject, eventdata, handles)

function slider_sigma_Callback(hObject, eventdata, handles)

function slider_buffer_Callback(hObject, eventdata, handles)

function slider_threshold_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

function slider_buffer_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

function slider_sigma_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

function axes1_CreateFcn(hObject, eventdata, handles)

