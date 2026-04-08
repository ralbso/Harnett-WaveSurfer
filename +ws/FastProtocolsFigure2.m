classdef FastProtocolsFigure2 < ws.AppFigure
    % FastProtocolsFigure2 — Modern uifigure-based Fast Protocols window.
    % Replaces FastProtocolsFigure + FastProtocolsController.
    
    properties (Access = protected)
        Table_
        ClearRowButton_
        SelectFileButton_
        SelectedRowIndex_
    end
    
    methods
        function self = FastProtocolsFigure2(model)
            self@ws.AppFigure(model, 'Fast Protocols', [440 220]) ;
            
            if ~isempty(model) && isvalid(model)
                model.subscribeMe(self, 'UpdateFastProtocols', '', 'update') ;
                model.subscribeMe(self, 'DidSetState', '', 'updateControlEnablement') ;
            end
            
            self.SelectedRowIndex_ = [] ;
            self.update() ;
            self.show() ;
        end
    end
    
    methods (Access = protected)
        function createComponents_(self)
            self.GridLayout_.RowHeight = {'1x', 32} ;
            self.GridLayout_.ColumnWidth = {'1x'} ;
            self.GridLayout_.Padding = [10 10 10 10] ;
            self.GridLayout_.RowSpacing = 6 ;
            
            % Table
            self.Table_ = uitable(self.GridLayout_, ...
                'ColumnName', {'Protocol File', 'Action'}, ...
                'ColumnEditable', [true true], ...
                'ColumnFormat', {'char', {'Do Nothing', 'Play', 'Record'}}, ...
                'CellEditCallback', @(src, evt) self.tableCellEdited_(evt), ...
                'CellSelectionCallback', @(src, evt) self.tableCellSelected_(evt)) ;
            self.Table_.Layout.Row = 1 ;
            self.Table_.Layout.Column = 1 ;
            
            % Button bar
            buttonGrid = uigridlayout(self.GridLayout_, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x', 80, 10, 90}, ...
                'Padding', [0 0 0 0]) ;
            buttonGrid.Layout.Row = 2 ;
            buttonGrid.Layout.Column = 1 ;
            
            self.ClearRowButton_ = uibutton(buttonGrid, ...
                'Text', 'Clear Row', ...
                'ButtonPushedFcn', @(~,~) self.clearRowPushed_()) ;
            self.ClearRowButton_.Layout.Column = 2 ;
            
            self.SelectFileButton_ = uibutton(buttonGrid, ...
                'Text', 'Select File...', ...
                'ButtonPushedFcn', @(~,~) self.selectFilePushed_()) ;
            self.SelectFileButton_.Layout.Column = 4 ;
        end
        
        function updateControlPropertiesImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            
            nRows = model.NFastProtocols ;
            data = cell(nRows, 2) ;
            for i = 1:nRows
                data{i,1} = model.getFastProtocolProperty(i, 'ProtocolFileName') ;
                autoStart = model.getFastProtocolProperty(i, 'AutoStartType') ;
                data{i,2} = ws.titleStringFromStartType(autoStart) ;
            end
            self.Table_.Data = data ;
        end
        
        function updateControlEnablementImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            
            isIdle = isequal(model.State, 'idle') ;
            hasSelection = ~isempty(self.SelectedRowIndex_) ;
            
            self.ClearRowButton_.Enable = ws.onIff(isIdle && hasSelection) ;
            self.SelectFileButton_.Enable = ws.onIff(isIdle && hasSelection) ;
            self.Table_.Enable = ws.onIff(isIdle) ;
        end
        
        % --- Callbacks ---
        function tableCellSelected_(self, event)
            indices = event.Indices ;
            if ~isempty(indices)
                self.SelectedRowIndex_ = indices(1) ;
                self.Model_.do('set', 'IndexOfSelectedFastProtocol', indices(1)) ;
            end
            self.updateControlEnablement() ;
        end
        
        function tableCellEdited_(self, event)
            indices = event.Indices ;
            newValue = event.EditData ;
            rowIndex = indices(1) ;
            colIndex = indices(2) ;
            
            if colIndex == 1
                % Protocol file name
                self.Model_.do('setFastProtocolProperty', rowIndex, 'ProtocolFileName', newValue) ;
            elseif colIndex == 2
                % Action
                self.Model_.do('setFastProtocolProperty', rowIndex, 'AutoStartType', ws.startTypeFromTitleString(newValue)) ;
            end
        end
        
        function clearRowPushed_(self)
            try
                self.Model_.do('clearSelectedFastProtocol') ;
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function selectFilePushed_(self)
            filePickerInitialFolder = ws.Preferences.sharedPreferences().loadPref('LastProtocolFilePath') ;
            originalFileName = self.Model_.getSelectedFastProtocolProperty('ProtocolFileName') ;
            if ~isempty(originalFileName)
                filePickerInitialFolder = originalFileName ;
            end
            
            [filename, dirName] = uigetfile( ...
                {'*.wsp', 'WaveSurfer Protocol Files'; '*.*', 'All Files (*.*)'}, ...
                'Select a Protocol File', filePickerInitialFolder) ;
            
            if isequal(filename, 0)
                return
            end
            
            newFileName = fullfile(dirName, filename) ;
            self.Model_.do('setSelectedFastProtocolProperty', 'ProtocolFileName', newFileName) ;
        end
    end
    
end
