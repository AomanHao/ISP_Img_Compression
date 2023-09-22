%% �������
% ���˲��� www.aomanhao.top
% Github https://github.com/AomanHao
% CSDN https://blog.csdn.net/Aoman_Hao
%--------------------------------------


clear;
close all;
clc;

addpath('./method/');
addpath('./tools/');
pathname = './data/';

img_conf = dir(pathname);
img_name = {img_conf.name};
img_num = numel({img_conf.name})-2;

data_type = 'bmp'; % raw: raw data
%bmp: bmp data
conf.savepath = './result/';
if ~exist(conf.savepath,'var')
    mkdir(conf.savepath)
end

conf.remake=[];
for i = 1:img_num
    switch data_type
        case 'bmp'
            name = split(img_name{i+2},'.');
            conf.imgname = name{1};
            conf.imgtype = name{2};
            img = imread([pathname,img_name{i+2}]);
            figure;imshow(img);
            img_in = double(img);
            [m_img,n_img,z_img] = size(img_in);
    end
    
    if z_img == 3
        img_yuv =func_rgb2yuv(img_in);
    else
        img_yuv(:,:,1) = img_in;
        img_yuv(:,:,2) = 0;
        img_yuv(:,:,3) = 0;
    end
    
    compress_method = 'jepg';
    switch compress_method
        case 'jepg'
            %% ͼ��ѹ��
            conf.quality_scale = 0.5; % 0-1֮���ѹ������
            im_idct = func_image_compress_JEPG(img_yuv,conf);
            
            %% yuv->rgb
            rgb = uint8(func_yuv2rgb(im_idct));
            %% save result
            imwrite(rgb,strcat(conf.savepath,conf.imgname,'_',compress_method,'.jpg'),'jpg');
        case 'imwrite'
            
            imwrite(uint8(img_in),strcat(conf.savepath,conf.imgname,'_',compress_method,'.jpg'),'jpg','quality',50);
    end
    
    %% ��ѹ��ǰ���ѹ����
    lite_info = imfinfo(strcat(conf.savepath,conf.imgname,'_',compress_method,'.jpg'));
    lite_size = lite_info.FileSize; % BYTE before
    re_info = imfinfo([pathname,img_name{i+2}]);
    re_size = re_info.FileSize; % BYTE after
    compress_ratio(i,:) = lite_size/re_size;
    
end
