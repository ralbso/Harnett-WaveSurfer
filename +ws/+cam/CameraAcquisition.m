classdef CameraAcquisition < handle
    properties (Constant=true)
        frameRate = 62
        exposureTime = 15000
        roiPosition = [0 0 592 592]
        compressionQuality = 100
        LineIndicator = '  '
        codec = 'MPEG-4'
        ext = '.mp4'
        address = '169.254.99.158'
        port = 4545
        bytesAvailableCnt = 3
        
        cameraTTLPort = 'COM5'
        baudRate = 128000
    end
    
    properties (Constant=false)
        fallbackSweep = 101
    end
    
    properties
        rootpath
        client
        camera
        cameraSerial
        isAcquiring % Flag to track acquisition state
        previewFig
        previewAxes
    end
    
    methods
        function self = CameraAcquisition(rootpath)
            self.rootpath = rootpath;
            self.isAcquiring = false;

            self.client = tcpip(self.address, self.port, 'NetworkRole', 'client');
            self.client.Timeout = Inf;
            self.client.BytesAvailableFcnMode = 'byte';
            self.client.BytesAvailableFcnCount = self.bytesAvailableCnt;
            self.client.BytesAvailableFcn = @self.readDataFcn;
            fopen(self.client);
            
            self.cameraSerial = serial(self.cameraTTLPort, 'BaudRate', self.baudRate);
            fopen(self.cameraSerial);
            
            self.initializeCamera();
        end % CameraAcquisition init
        
        function initializeCamera(self)
            if isempty(self.camera)
                % connection takes time; give some feedback
                fprintf('%s Setting up camera\n', self.LineIndicator);
                % 08/07/2025: ignore dropped frames, keep acquiring
                %(might help prevent camera crashes)
                imaqmex('feature', '-gigeDisablePacketResend', true);
                self.camera = videoinput('gige', 1, 'Mono8');
                fprintf('%s Camera connection established\n', self.LineIndicator);
                self.camera.ROIPosition = self.roiPosition;
                
                src = self.camera.Source;
                src.ExposureTime = self.exposureTime;
                src.AcquisitionFrameRate = self.frameRate;
                src.PacketDelay = 34*1.5;
                src.PacketSize = 9000;

                config = triggerinfo(self.camera);
                triggerconfig(self.camera, config(2));
                self.camera.FramesPerTrigger = Inf;
                self.camera.LoggingMode = 'disk';
                self.camera.FramesAcquiredFcnCount = 1;
                self.camera.FramesAcquiredFcn = @self.frameAcquiredTTL;

                vidRes = self.camera.VideoResolution;
                nBands = self.camera.NumberOfBands;
                
                % create custom preview window
                f = figure('Toolbar', 'none', ...
                    'Menubar', 'none', ...
                    'NumberTitle', 'Off', ...
                    'Name', 'Mouse Preview', ...
                    'InnerPosition', [-450 643 449 407], ...
                    'Units', 'pixels', ...
                    'Color', 'k', ...
                    'Pointer', 'cross');
                
                % Create the text labels
                hBlackStrip = uicontrol('style', 'text', 'String', 'strip', ...
                    'Units', 'normalized', 'Position', [0 -0.05 1 0.08], ...
                    'ForegroundColor', 'w', 'BackgroundColor', 'k', ...
                    'FontName', 'FixedWidth');
                hTextLabel = uicontrol('style','text','String','Timestamp', ...
                    'Units','normalized', 'Position',[0.78 -0.05 0.22 0.08], ...
                    'ForegroundColor', 'w', 'BackgroundColor', 'k', ...
                    'FontName', 'FixedWidth');
                hStatusLabel = uicontrol('style', 'text', 'String', 'Status', ...
                    'Units', 'normalized', 'Position', [0 -0.05 0.32 0.08], ...
                    'ForegroundColor', 'w', 'BackgroundColor', 'k', ...
                    'FontName', 'FixedWidth');
                hFramerateLabel = uicontrol('style', 'text', 'String', 'Framerate', ...
                    'Units', 'normalized', 'Position', [0.45 -0.05 0.2 0.08], ...
                    'ForegroundColor', 'w', 'BackgroundColor', 'k', ...
                    'FontName', 'FixedWidth');
                
                ax = axes('Parent', f, 'Units', 'normalized', 'InnerPosition', [0 0 1.1 1]);
                hImage = image(ax, zeros(vidRes(2)/2, vidRes(1)/2, nBands));
                
                setappdata(hImage, 'UpdatePreviewWindowFcn', @self.customPreviewFcn);
                setappdata(hImage, 'HandleToTimestampLabel', hTextLabel);
                setappdata(hImage, 'HandleToStatusLabel', hStatusLabel);
                setappdata(hImage, 'HandleToFramerateLabel', hFramerateLabel);
                setappdata(hImage, 'HandleToBlackStrip', hBlackStrip);
                
                preview(self.camera, hImage);
                
            end
        end % initializeCamera
        
        function beginCameraAcquisition(self, pipette, sweep)
            % prevent starting if already acquiring
            if self.isAcquiring
                fprintf('%s WARNING: Camera already acquiring, ignoring start command\n', self.LineIndicator);
                return
            end
            
            fpath = [self.rootpath '\p' num2str(pipette) '_' num2str(sweep, '%04.f')];
            if isfile([fpath self.ext])
                fpath = [self.rootpath '\p' num2str(pipette) '_' num2str(self.fallbackSweep, '%04.f')];
                self.fallbackSweep = self.fallbackSweep + 1;
            end
            
            logger = VideoWriter([fpath self.ext], self.codec);
            logger.Quality = self.compressionQuality;
            logger.FrameRate = self.frameRate;            
            self.camera.DiskLogger = logger;
                        
            fprintf('%s Acquiring video at %s\n', self.LineIndicator, [fpath self.ext]);
            if ~isempty(self.camera)
                if ~isrunning(self.camera)
                    start(self.camera);
                    trigger(self.camera);
                    self.isAcquiring = true;
                elseif isrunning(self.camera) && ~islogging(self.camera)
                    trigger(self.camera);
                    self.isAcquiring = true;
                end
            end
        end % beginCameraAcquisition
        
        function safelyStopCamera(self)
            if ~isempty(self.camera)
                fprintf('%s Safely stopping camera\n', self.LineIndicator);
                if ~self.isAcquiring
                    fprintf('%s Camera not acquiring, nothing to stop\n', self.LineIndicator);
                    return;
                end
                
                if isrunning(self.camera)
                    % disable callback first to prevent race conditions
                    self.camera.FramesAcquiredFcn = '';
                    stop(self.camera)
                    
                    fprintf('%s Stopped camera\n', self.LineIndicator);
                    fprintf('%s Logged %d/%d frames\n', self.LineIndicator, self.camera.DiskLoggerFrameCount, self.camera.FramesAcquired)
                    
                    % safely close DiskLogger with error handling
                    if ~isempty(self.camera.DiskLogger)
                        try
                            close(self.camera.DiskLogger);
                            fprintf('%s Closed DiskLogger\n\n', self.LineIndicator);
                        catch ME
                            fprintf('%s ERROR closing DiskLogger: %s\n', ...
                                self.LineIndicator, ME.message);
                        end
                        
                        % re-enable callback for next acquisition
                        self.camera.FramesAcquiredFcn = @self.frameAcquiredTTL;
                        
                        % clear disklogger reference
                        self.camera.DiskLogger = [];
                    end
                    self.isAcquiring = false;
 
                end
            end
        end % safelyStopCamera
        
        function safelyDeleteCamera(self)
            % stop acquisition first if running
            if self.isAcquiring
                self.safelyStopCamera();
            end
            
            fclose(self.cameraSerial);
            if ~isempty(self.camera)
                fprintf('%s Safely deleting camera object\n', self.LineIndicator);
                
                % disable callback before deletion
                self.camera.FramesAcquiredFcn = '';
                if ~isrunning(self.camera)
                    delete(self.camera)
                    
                    if strcmp(self.client.status, 'open')
                        fclose(self.client);
                    end
                    
                else
                    closepreview(self.camera)
                    stop(self.camera)
                    
                    % wait briefly for stop to complete
                    pause(0.2);
                    
                    delete(self.camera)
                    clear(self.camera)
                    
                    if strcmp(self.client.status, 'open')
                        fclose(self.client);
                    end
                end
            end
        end % safelyDeleteCamera
        
        function readDataFcn(self, src, ~)
            try
                arr = fread(src, 3);
                if ~isempty(arr)
                    t = arr(1);
                    switch t
                        case 1
                            pipette = arr(2);
                            sweep = arr(3);
                            self.beginCameraAcquisition(pipette, sweep);
                        case 2
                            self.safelyStopCamera;
                        case 3
                            self.safelyDeleteCamera;
                    end
                end
            catch ME
                fprintf('%s ERROR in readDataFcn: %s\n', ...
                    self.LineIndicator, ME.message);
                fprintf('%s Stack: %s\n', ...
                    self.LineIndicator, ME.stack(1).name);
            end
        end % readDataFcn
        
        function frameAcquiredTTL(self, ~, ~)
            try
                if strcmp(self.cameraSerial.Status, 'open') && self.isAcquiring
                    fwrite(self.cameraSerial, 'a');
                end
            catch ME
                if ~contains(ME.message, 'not open')
                    fprintf('%s WARNING: TTL error: %s\n', ...
                        self.LineIndicator, ME.message);
                end
            end
        end % frameAcquiredTTL
        
        function customPreviewFcn(~, ~, event, himage)
            % get timestamp for frame
            curr_timestamp = event.Timestamp;
            curr_status = event.Status;
            curr_framerate = event.FrameRate;
            
            % get handle to text label uicontrol
            ht = getappdata(himage, 'HandleToTimestampLabel');
            hs = getappdata(himage, 'HandleToStatusLabel');
            hf = getappdata(himage, 'HandleToFramerateLabel');
            
            % set the value of the text labels
            ht.String = curr_timestamp;
            hs.String = curr_status;
            hf.String = curr_framerate;
            
            % display image data
            himage.CData = event.Data;
        end

    end % methods
    
end % classdef