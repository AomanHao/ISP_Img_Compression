function im_idct = func_image_compress_JEPG(img_yuv,conf)

[m_img,n_img,z_img] = size(img_yuv); 
%% ��ɫ��ͼ���²���
img_yuv_samp = func_subsampling_420(img_yuv);

%% ��ͼ���Ϊ8*8��DCT�任
im_dct = func_dct(img_yuv_samp);

%% ���� ������������Ϣ����
% ʹ��JPEG2000�Ƽ��ı�׼����������ͱ�׼ɫ��������
quantified =  func_quantization(im_dct,conf.quality_scale);

%% zigzag
% ��ÿ??8*8�����z�α��룬�γ�????64*1����??
% ??Ҫ��y,cb,cr����ͨ���н��в�����??����??��������64*4096*3�ľ�??
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
    % im2col()�ɽ�ÿ��8*8�ӿ�չ��??�����������ٽ���ͬ�ӿ����ɵ�������ƴ��һ??
    col_block = im2col(ch, [8 8], 'distinct');
    after_zigzag(:,:,i) = col_block(order,:);
end

%% rlc
% ??64*4096*3��������ÿ��ͨ���������ų�һ�У�ת��??26214*3�����ݣ��ٶ�ÿ��ͨ���ֱ����γ̱�??
% ��???�����ִ������ֱ����rlc_count_��rlc_value_??
% ÿ��ͨ��������Ϊcount��value����������һ������???��������һ����6����??
col_vec_y = after_zigzag(:,:,1);
col_vec_y = col_vec_y(:);
col_vec_cb = after_zigzag(:,:,2);
col_vec_cb = col_vec_cb(:);
col_vec_cr = after_zigzag(:,:,3);
col_vec_cr = col_vec_cr(:);
[rlc_count_y,rlc_value_y] = rlc_enc(col_vec_y);
[rlc_count_cb,rlc_value_cb] = rlc_enc(col_vec_cb);
[rlc_count_cr,rlc_value_cr] = rlc_enc(col_vec_cr);

% ����??������rlc��ѹ����??
% count�����е�ÿ������ȡ???��Χ��[1,63]��������uint8�洢
% value��������ڸ���������ȡ����???ԶС��256��������??���ؼ���??��ƫ�ƣ�����uint8�洢
% ��֮�������õ��ı�������*8��ΪRLCѹ������??����??
% ��quality_scale=0.5��RLC�����ѹ���ȴﵽ10����

uint8_count=size(rlc_count_y,2)+size(rlc_count_cb,2)+size(rlc_count_cr,2) * 2;
bitcost_rlc = uint8_count*8;
ratio_rlc = m_img*n_img*3*8 / bitcost_rlc;

%% huffman
% ���γ̱����6�������ֱ�����������??
% ��rlc_value_y����Ϊ����HC_Struct_value_y.HC_codes�洢�˱����HC_Struct_value_y.HC_tabENC�洢��ԭʼ���ݱ����Ľ�??
% ALL_CELL �洢�ˣ�ԭ��?? | �����������ķ�?? | �÷��ų��ִ�����
% MEAN_LEN �洢��ƽ����??
HC_Struct_count_y = whuffencode(rlc_count_y);
HC_Struct_count_cb = whuffencode(rlc_count_cb);
HC_Struct_count_cr = whuffencode(rlc_count_cr);

[HC_Struct_value_y, ALL_CELL,~,~,MEAN_LEN] = whuffencode(rlc_value_y);
HC_Struct_value_cb = whuffencode(rlc_value_cb);
HC_Struct_value_cr = whuffencode(rlc_value_cr);

%% inverse_huffman
% ���뺯�����Զ���ԭ���м���һ��ƫ��???��ʹ����������������в����ڸ�����0�����Խ���ʱ����Ҫ���������� + min(rlc_count_y) - 1
huffdecoded_count_y = whuffdecode(HC_Struct_count_y.HC_codes, HC_Struct_count_y.HC_tabENC) + min(rlc_count_y) - 1;
huffdecoded_count_cb = whuffdecode(HC_Struct_count_cb.HC_codes, HC_Struct_count_cb.HC_tabENC) + min(rlc_count_cb) - 1;
huffdecoded_count_cr = whuffdecode(HC_Struct_count_cr.HC_codes, HC_Struct_count_cr.HC_tabENC) + min(rlc_count_cr) - 1;

huffdecoded_value_y = whuffdecode(HC_Struct_value_y.HC_codes, HC_Struct_value_y.HC_tabENC) + min(rlc_value_y) - 1;
huffdecoded_value_cb = whuffdecode(HC_Struct_value_cb.HC_codes, HC_Struct_value_cb.HC_tabENC) + min(rlc_value_cb) - 1;
huffdecoded_value_cr = whuffdecode(HC_Struct_value_cr.HC_codes, HC_Struct_value_cr.HC_tabENC) + min(rlc_value_cr) - 1;

% ����??������huffman��ѹ����??
% HC_tabENC�ڴ�ŵ��Ƕ��������У����䳤����ɻ�ñ�����??����??
% ��quality_scale=0.5�������������ѹ���ȴﵽ16����
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