function [ind]=maxvol2(a)
%[IND]=MAXVOL2(A)
%Computes maximal volume submatrix in n x r matrix A
%Returns rows indices that contain maximal volume submatrix
%
%
% TT Toolbox 1.1, 2009-2010
%
%This is TT Toolbox, written by Ivan Oseledets, Olga Lebedeva
%Institute of Numerical Mathematics, Moscow, Russia
%webpage: http://spring.inm.ras.ru/osel
%
%For all questions, bugs and suggestions please mail
%ivan.oseledets@gmail.com
%---------------------------
n=size(a,1); r=size(a,2);
if ( n == r ) 
    ind = 1:r;
    return
end 
%Initialize
[l,u,p]=lu(a,'vector');
%p=randperm(n);
ind=p(1:r);
b=a(p,:);
sbm=a(ind,:);
z=b(r+1:n,:)/sbm;
%Start iterations
niters=100;
eps=5e-2; %Stopping accuracy
iter=0;
while (iter <= niters);
[mx,pv]=max((abs(z))');
[mx0,pv0]=max(mx);
if ( mx0 <= 1 + eps ) 
    ind=sort(ind);
    return
    
end 
%Swap i0-th row with j0-th row
i0=pv0;
j0=pv(i0);
i=p(i0+r);
p(i0+r)=p(j0);
p(j0)=i;
bb=z(:,j0);
bb(i0)=bb(i0)+1;
cc=z(i0,:);
cc(j0)=cc(j0)-1;
z=z-bb*cc./z(i0,j0);
iter=iter+1;
ind=p(1:r);
ind=sort(ind);
end

return
end