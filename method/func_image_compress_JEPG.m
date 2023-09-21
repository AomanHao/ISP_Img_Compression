function im_idct = func_image_compress_JEPG(img_yuv,conf)

[m_img,n_img,z_img] = size(img_yuv); 
%% 对色度图像下采样
img_yuv_samp = func_subsampling_420(img_yuv);

%% 对图像分为8*8并DCT变换
im_dct = func_dct(img_yuv_samp);

%% 量化 丢弃不显著信息分量
% 使用JPEG2000推荐的标准亮度量化表和标准色差量化表
quantified =  func_quantization(im_dct,conf.quality_scale);

%% zigzag
% 对每??8*8块进行z形编码，形成????64*1的向??
% ??要对y,cb,cr三个通道中进行操作，??以这??步会生成64*4096*3的矩??
zigzag=[ 1  2  9 17 10  3  4 11
    18 25 33 26 19 12  5  6
    13 20 27 34 41 49 42 35
    28 21 14  7  8 15 22 29
    36 43 50 57 58 51 44 37
    30 23 16 24 31 38 45 52
    59 60 53 46 39 32 40 47
    54 61 62 55 48 56 63 64];
order = reshape(zigzag',1,64);
for i=1:3
    ch = quantified(:,:,i);
    % im2col()可将每个8*8子块展成??个列向量，再将不同子块生成的列向量拼在一??
    col_block = im2col(ch, [8 8], 'distinct');
    after_zigzag(:,:,i) = col_block(order,:);
end

%% rlc
% ??64*4096*3的数据中每个通道的数据排成一列，转换??26214*3的数据，再对每个通道分别做游程编??
% （???，出现次数）分别存在rlc_count_和rlc_value_??
% 每个通道被编码为count、value两个分量，一共三个???道，所以一共有6个分??
col_vec_y = after_zigzag(:,:,1);
col_vec_y = col_vec_y(:);
col_vec_cb = after_zigzag(:,:,2);
col_vec_cb = col_vec_cb(:);
col_vec_cr = after_zigzag(:,:,3);
col_vec_cr = col_vec_cr(:);
[rlc_count_y,rlc_value_y] = rlc_enc(col_vec_y);
[rlc_count_cb,rlc_value_cb] = rlc_enc(col_vec_cb);
[rlc_count_cr,rlc_value_cr] = rlc_enc(col_vec_cr);

% 计算??下做完rlc的压缩情??
% count分量中的每个数字取???范围是[1,63]，可以用uint8存储
% value分量里存在负数，但能取到的???远小于256个，可以??单地加上??个偏移，再用uint8存储
% 总之，这里用到的变量个数*8即为RLC压缩后所??比特??
% 当quality_scale=0.5，RLC编码后压缩比达到10左右

uint8_count=size(rlc_count_y,2)+size(rlc_count_cb,2)+size(rlc_count_cr,2) * 2;
bitcost_rlc = uint8_count*8;
ratio_rlc = m_img*n_img*3*8 / bitcost_rlc;

%% huffman
% 对游程编码的6个分量分别做哈夫曼编??
% 以rlc_value_y分量为例，HC_Struct_value_y.HC_codes存储了编码表，HC_Struct_value_y.HC_tabENC存储了原始数据编码后的结??
% ALL_CELL 存储了（原符?? | 哈夫曼编码后的符?? | 该符号出现次数）
% MEAN_LEN 存储了平均码??
HC_Struct_count_y = whuffencode(rlc_count_y);
HC_Struct_count_cb = whuffencode(rlc_count_cb);
HC_Struct_count_cr = whuffencode(rlc_count_cr);

[HC_Struct_value_y, ALL_CELL,~,~,MEAN_LEN] = whuffencode(rlc_value_y);
HC_Struct_value_cb = whuffencode(rlc_value_cb);
HC_Struct_value_cr = whuffencode(rlc_value_cr);

%% inverse_huffman
% 编码函数会自动给原序列加上一个偏移???，使得送入编码器的序列不存在负数和0。所以解码时则需要将整个序列 + min(rlc_count_y) - 1
huffdecoded_count_y = whuffdecode(HC_Struct_count_y.HC_codes, HC_Struct_count_y.HC_tabENC) + min(rlc_count_y) - 1;
huffdecoded_count_cb = whuffdecode(HC_Struct_count_cb.HC_codes, HC_Struct_count_cb.HC_tabENC) + min(rlc_count_cb) - 1;
huffdecoded_count_cr = whuffdecode(HC_Struct_count_cr.HC_codes, HC_Struct_count_cr.HC_tabENC) + min(rlc_count_cr) - 1;

huffdecoded_value_y = whuffdecode(HC_Struct_value_y.HC_codes, HC_Struct_value_y.HC_tabENC) + min(rlc_value_y) - 1;
huffdecoded_value_cb = whuffdecode(HC_Struct_value_cb.HC_codes, HC_Struct_value_cb.HC_tabENC) + min(rlc_value_cb) - 1;
huffdecoded_value_cr = whuffdecode(HC_Struct_value_cr.HC_codes, HC_Struct_value_cr.HC_tabENC) + min(rlc_value_cr) - 1;

% 计算??下做完huffman的压缩情??
% HC_tabENC内存放的是二进制序列，求其长度则可获得编码所??比特??
% 当quality_scale=0.5，哈夫曼编码后压缩比达到16左右
bitcost_huffman = length(HC_Struct_count_y.HC_tabENC) + length(HC_Struct_count_cb.HC_tabENC)+ length(HC_Struct_count_cr.HC_tabENC) ...
    + length(HC_Struct_value_y.HC_tabENC) + length(HC_Struct_value_cb.HC_tabENC) + length(HC_Struct_value_cr.HC_tabENC);
ratio_huffman = m_img*n_img*3*8 / bitcost_huffman;

%% inverse_rlc
inverse_rlc_y = rlc_dec(huffdecoded_count_y,huffdecoded_value_y);
inverse_rlc_y = reshape(inverse_rlc_y, size(after_zigzag(:,:,1),1), size(after_zigzag(:,:,1),2));
inverse_rlc_cb = rlc_dec(huffdecoded_count_cb,huffdecoded_value_cb);
inverse_rlc_cb = reshape(inverse_rlc_cb, size(after_zigzag(:,:,1),1), size(after_zigzag(:,:,1),2));
inverse_rlc_cr = rlc_dec(huffdecoded_count_cr,huffdecoded_value_cr);
inverse_rlc_cr = reshape(inverse_rlc_cr, size(after_zigzag(:,:,1),1), size(after_zigzag(:,:,1),2));
inverse_rlc = cat(3,inverse_rlc_y,inverse_rlc_cb,inverse_rlc_cr);

%% inverse_zigzag
rev = zeros(1,64);
for k = 1:length(order)
    rev(k) = find(order==k);
end

for i=1:3
    ch = inverse_rlc(:,:,i);
    rearrange = ch(rev,:);
    inverse_zigzag(:,:,i) = col2im(rearrange, [8 8], [m_img n_img], 'distinct');
end

%% inverse_quantization
iquantified = func_iquantization(inverse_zigzag, conf.quality_scale);

%% IDCT
im_idct = func_idct(iquantified);