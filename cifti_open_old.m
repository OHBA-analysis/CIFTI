function [cifti, data] = cifti_open_old( cifti_file, verbose )
% Open a CIFTI file by converting to GIFTI external binary first and then using the GIFTI toolbox

    if nargin < 2, verbose = true; end

    if verbose
       disp(['[cifti_open_old] Opening file "' cifti_file '"...']); 
    end
    
    % Create temporary file to convert to a GIFTI file
    gifti_file = [tempname '.gii'];

    % Convert CIFTI to GIFTI using WorkBench
    wb_call(['cifti-convert -to-gifti-ext ' cifti_file ' ' gifti_file]);

    % Open converted GIFTI file
    cifti = gifti(gifti_file);
    
    % Extract index data
    if nargout > 1
        data = parse_xml_metadata( cifti.private.data{1}.metadata.value, cifti.cdata );
    end

    % Delete temporary GIFTI files
    unix(['rm ' gifti_file ' ' gifti_file '.data']);

    
    
    
    function BM = parse_xml_metadata( str, data )
        
        tree=xmltree(str);
        
        % find transformation matrix
        bmi=[];
        IJK2XYZi=[];
        XYZ2IJKi=[];
        for ctr=1:length(tree)
            try NAME=get(tree,ctr,'name'); catch, NAME=[]; end
            if strcmp(NAME,'BrainModel')
                bmi=[bmi ctr];
            elseif strcmp(NAME,'TransformationMatrixVoxelIndicesIJKtoXYZ')
                IJK2XYZi=[IJK2XYZi ctr];
            elseif strcmp(NAME,'TransformationMatrixVoxelIndicesXYZtoIJK')
                XYZ2IJKi=[XYZ2IJKi ctr];
            end
        end
        if length(IJK2XYZi)>2 || length(XYZ2IJKi)>2
            error('Too many transformation matrices found.');
        end
        
        
        BM=cell(length(bmi),1);
        for bm=1:length(bmi)
        
            attr=get(tree,bmi(bm),'attributes');
            for b=1:length(attr)
                KEY=attr{b}.key;
                VAL=attr{b}.val;
                BM{bm}.(KEY) = VAL;
            end
            
            try ch=get(tree,bmi(bm),'contents'); catch, ch=[]; end
            while ~isempty(ch)
                
                cc = ch(1);
                ch(1)=[];
                
                try nch=get(tree,cc,'contents'); catch, nch=[]; end
                ch = union(ch,nch);
                if strcmp(get(tree,cc,'type'),'element')
                    
                    try ccc=get(tree,cc,'contents'); catch, ccc=[]; end
                    if ~isempty(ccc) && strcmp(get(tree,ccc,'type'),'chardata')
                    switch get(tree,cc,'name')
                        
                        case 'VertexIndices'

                            didx   = 1 + str2num(get(tree,ccc,'value'));
                            icount = str2num(BM{bm}.IndexCount);
                            ioff   = str2num(BM{bm}.IndexOffset);
                            midx   = (ioff+1) : (ioff+icount);

                            if length(didx) ~= icount
                                error('Data dimension does not agree with index count!')
                            end
                            BM{bm}.SurfaceIndices = didx;
                            BM{bm}.DataIndices    = midx;
                            BM{bm}.Data           = data(midx,:);
                        
                        case 'VoxelIndicesIJK'

                            didx   = 1 + str2num(get(tree,ccc,'value'));
                            icount = str2num(BM{bm}.IndexCount);
                            ioff   = str2num(BM{bm}.IndexOffset);
                            midx   = (ioff+1) : (ioff+icount);

                            if length(didx)/3 == icount
                                didx=reshape(didx,[3,length(didx)/3])';
                            else
                                error('Data dimension does not agree with index count!')
                            end
                            BM{bm}.VolumeIndicesIJK = didx;
                            BM{bm}.DataIndices      = midx;
                            BM{bm}.Data             = data(midx,:);

                            if length(IJK2XYZi) > 0
                                XT=struct;
                                attr=get(tree,IJK2XYZi,'attributes');
                                for b=1:length(attr)
                                    KEY=attr{b}.key;
                                    VAL=attr{b}.val;
                                    XT.(KEY) = VAL;
                                end
                                ch=get(tree,IJK2XYZi,'contents');
                                for c=ch';
                                    if strcmp(get(tree,c,'type'),'chardata')
                                        trx=reshape(str2num(get(tree,c,'value')),[4 4]);
                                    end
                                end
                                XT.TransformMatrix = trx;
                                BM{bm}.IJK2XYZ = XT;
                            end
                        
                        case 'VoxelIndicesXYZ'
                            
                            didx   = str2num(get(tree,ccc,'value')); % isn't there a +1?
                            icount = str2num(BM{bm}.IndexCount);
                            ioff   = str2num(BM{bm}.IndexOffset);
                            midx   = (ioff+1) : (ioff+icount);

                            if length(didx)/3 == icount
                                didx=reshape(didx,[3,length(didx)/3])';
                            else
                                error('Data dimension does not agree with index count!')
                            end
                            BM{bm}.VolumeIndicesXYZ = didx;
                            BM{bm}.DataIndices      = midx;
                            BM{bm}.Data             = data(midx,:);
                            
                            if length(XYZ2IJKi) > 0
                                XT=struct;
                                attr=get(tree,XYZ2IJKi,'attributes');
                                for b=1:length(attr)
                                    KEY=attr{b}.key;
                                    VAL=attr{b}.val;
                                    XT.(KEY) = VAL;
                                end
                                ch=get(tree,XYZ2IJKi,'contents');
                                for c=ch';
                                    if strcmp(get(tree,c,'type'),'chardata')
                                        trx=reshape(str2num(get(tree,c,'value')),[4 4]);
                                    end
                                end
                                XT.TransformMatrix = trx;
                                BM{bm}.XYZ2IJK = XT;
                            end
                        
                    end
                    end
                    
                end
            end
        end
        
    end

end

