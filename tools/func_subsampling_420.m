function out = func_subsampling_420( im)
    out = im;
    % ת����
    out(:, 2:2:end, 2) = out(:, 1:2:end-1, 2);
    out(:, 2:2:end, 3) = out(:, 1:2:end-1, 3);
    % ת����
    out(2:2:end, :, 2) = out(1:2:end-1, :, 2);
    out(2:2:end, :, 3) = out(1:2:end-1, :, 3);
end