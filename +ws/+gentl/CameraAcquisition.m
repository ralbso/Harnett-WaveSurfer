classdef CameraAcquisition < handle
    properties (Constant=true)
        frameRate = 62
        exposureTime = 15000
        roiPosition = [0 0 592 592];
        compressionQuality = 100
        
        LineIndicator = '  '
        codec = 'MPEG-4'
        ext = '.mp4'
        user = 'Raul'
    end
    
    properties
        fpath
        client
        camera
        nextRunCnt
    end
    
    methods
        function self = CameraAcquisition(fpath)
            self.fpath = fpath;

            [~, hostname] = system('hostname');
            hostname = string(strtrim(hostname));
            address = resolvehost(hostname, 'address');
            self.client = tcpip(address, 4545, 'NetworkRole', 'client');
            self.client.BytesAvailableFcnCount = 1;
            self.client.BytesAvailableFcnMode = 'byte';
            self.client.BytesAvailableFcn = @self.readDataFcn;
            fopen(self.client);

            self.initializeCamera();
            self.nextRunCnt = 1;
        end
        
        function initializeCamera(self)
            if isempty(self.camera)
                fprintf('%s Setting up camera\n', self.LineIndicator);
                self.camera = videoinput('gentl', 1, 'Mono8');
                fprintf('%s Camera connection established\n', self.LineIndicator);
                
                self.camera.ROIPosition = self.roiPosition;
                src = self.camera.Source;
                src.ExposureTime = self.exposureTime;
                src.AcquisitionFrameRate = self.frameRate;

                config = triggerinfo(self.camera);
                triggerconfig(self.camera, config(2));
                self.camera.FramesPerTrigger = Inf;
                self.camera.LoggingMode = 'disk';

                preview(self.camera);
            end
        end % func
        
        function beginCameraAcquisition(self)
            fname = [self.fpath '\' num2str(self.nextRunCnt) self.ext];
            logger = VideoWriter(fname, self.codec);
            logger.Quality = self.compressionQuality;
            logger.FrameRate = self.frameRate;            
            self.camera.DiskLogger = logger;
                        
            fprintf('%s Acquiring video at %s\n', self.LineIndicator, fname);
            if ~isempty(self.camera)
                if ~isrunning(self.camera)
                    start(self.camera);
                    trigger(self.camera);
                elseif isrunning(self.camera) && ~islogging(self.camera)
                    trigger(self.camera);
                end
            end
            self.nextRunCnt = self.nextRunCnt + 1;
        end % func
        
        function safelyStopCamera(self)
            if ~isempty(self.camera)
                fprintf('%s Safely stopping camera\n', self.LineIndicator);
                stop(self.camera)
            end
        end % func
        
        function safelyDeleteCamera(self)
            if ~isempty(self.camera)
                fprintf('%s Safely deleting camera object\n', self.LineIndicator);
                if ~isrunning(self.camera)
                    delete(self.camera)
                    
                    if strcmp(self.client.status, 'open')
                        fclose(self.client);
                    end
                    
                else
                    closepreview(self.camera)
                    stop(self.camera)
                    delete(self.camera)
                    
                    if strcmp(self.client.status, 'open')
                        fclose(sefl.client);
                    end
                end
            end
        end % func
        
        function readDataFcn(self, src, ~)
            t = fread(src, 3);
            switch t
                case 1
                    self.beginCameraAcquisition;
                case 2
                    self.safelyStopCamera;
                case 3
                    self.safelyDeleteCamera;
            end
        end

    end % methods
    
end % classdef