function out = func_dct(image)
    T = dctmtx(8); % 8*8DCT
    % dctmtx(N)��������N*N��DCT�任����
    % ��ͼ����ж�άDCT�任�����ַ�����
    %   1 ֱ��ʹ��dct2()������
    %   2 ��dctmtx()��ȡDCT�任������T��A��T'�����任T'��A��T
    func=@(block) T*block.data*T';
    for i=1:3
        out(:,:,i) = blockproc(image(:,:,i), [8 8], func);
        % blkproc����Ϊ�ֿ������������������8*8�Ŀ�ִ��DCT��
        % ���ڲ�����������������Զ���0����ұ�Ե���±�Ե��
        % �ڼ���������Զ�ɾ������
    end
end