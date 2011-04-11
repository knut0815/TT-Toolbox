function [c] = mtimes(a,b,varargin)
%[C]=MTIMES(A,B) --- multiplies TT-matrix A by TT-vector B, or
%matrix-by-number
%[C]=MTIMES(A,B,EPS) --- multiplies TT-matrix A by TT-vector B using
%Krylov-DMRG method with accuracy EPS
%[C]=MTIMES(A,B,EPS,NSWP) --- the same, number of sweeps is specified also
%[C]=MTIMES(A,B,EPS,NSWP,Y) --- the same, initial approximation is
%specified also
%Implement multiplication for a tt_tensor and 
%matrix-by-vector product

if (isa(a,'tt_matrix') && isa(b,'double') && numel(b) == 1 || (isa(b,'tt_matrix') && isa(a,'double') && numel(a) == 1) )
   c=tt_matrix;
    if (  isa(b,'double') )
      c.n=a.n; c.m=a.m; c.tt=(a.tt)*b;
   else
      c.n=b.n; c.m=b.m; c.tt=(b.tt)*a;
   end
elseif ( isa(a,'tt_matrix') && isa(b,'tt_tensor') && nargin == 2)
    %Put "zaglushka" in it
    c=tt_tensor(tt_mv(core(a),core(b)));
     return
     %Replace zaglushka
     c=tt_tensor;
     n=a.n; m=a.m; crm=a.tt.core; psm=a.tt.ps; d=a.tt.d; rm=a.tt.r;
     rv=b.r; crv=b.core; psv=b.ps; 
     rp=rm.*rv; 
     psp=cumsum([1;n.*rp(1:d).*rp(2:d+1)]);
     sz=dot(n.*rp(1:d),rp(2:d+1));
     crp=zeros(sz,1);
     c.d=d;
     c.r=rp;
     c.n=n;
     c.ps=psp;
     for i=1:d
        mcur=crm(psm(i):psm(i+1)-1);
        vcur=crv(psv(i):psv(i+1)-1);
        mcur=reshape(mcur,[rm(i)*n(i),m(i),rm(i+1)]);
        mcur=permute(mcur,[1,3,2]); mcur=reshape(mcur,[rm(i)*n(i)*rm(i+1),m(i)]);
        vcur=reshape(vcur,[rv(i),m(i),rv(i+1)]);
        vcur=permute(vcur,[2,1,3]); vcur=reshape(vcur,[m(i),rv(i),rv(i+1)]);
        pcur=mcur*vcur; %pcur is now rm(i)*n(i)*rm(i+1)*rv(i)*rv(i+1)
        pcur=reshape(pcur,[rm(i),n(i),rm(i+1),rv(i),rv(i+1)]);
        pcur=permute(pcur,[1,4,2,3,5]); 
        crp(psp(i):psp(i+1)-1)=pcur(:);
     end
     c.core=crp;
     %Simple cycle through cores
    %fprintf('matrix-by-vector not implemented yet \n');
elseif ( isa(a,'tt_tensor') && isa(b,'tt_matrix') && nargin == 2)
        fprintf('vector-by-matrix not implemented yet \n');
elseif ( isa(a,'tt_matrix') && isa(b,'double') && nargin == 2 )
    %TT-matrix by full vector product
    n=a.n; m=a.m; tt=a.tt; cra=tt.core; d=tt.d; ps=tt.ps; r=tt.r;
    b=reshape(b,m'); c=b;
    for k=1:d
      %c is rk*jk...jd*(i1..ik-1) tensor, conv over  
      %core is r(i)*n(i)*r(i+1)
      cr=cra(ps(k):ps(k+1)-1);
      cr=reshape(cr,[r(k),n(k),m(k),r(k+1)]);
      cr=permute(cr,[2,4,1,3]); cr=reshape(cr,[n(k)*r(k+1),r(k)*m(k)]);
      M=numel(c);
      c=reshape(c,[r(k)*m(k),M/(r(k)*m(k))]);
      c=cr*c; c=reshape(c,[n(k),numel(c)/n(k)]);
      c=permute(c,[2,1]);
    end
    c=c(:); c=reshape(c,[numel(c),1]);
    elseif ( isa(a,'tt_matrix') && isa(b,'tt_matrix') && nargin == 2)
    %fprintf('matrix-by-matrix not implemented yet \n');
    c=tt_matrix(tt_mm(core(a),core(b)));
elseif ( isa(a,'tt_matrix') && isa(b,'tt_tensor') && nargin > 3)
    c=mvk(a,b,varargin);
    fprintf('Krylov matrix-by-vector not implemented yet \n');
    
elseif ( isa(a,'tt_matrix') && isa(b,'tt_matrix') && nargin == 3)
    fprintf('Krylov matrix-by-matrix not implemented yet \n');

   
end