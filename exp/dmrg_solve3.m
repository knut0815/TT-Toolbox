function [x]=dmrg_solve3(a,y,x0,eps,tol,rmax,nswp)
%[X]=DMRG_SOLVE3(A,Y,X0,EPS,TOL,RMAX,NSWP)
%Solve approximately equation AX = Y, where
%A is a TT-matrix, Y is a TT-vector, 
%Maximal rank of the solution is RMAX, 
%Maximal numbero of sweeps is NSWP
%By default NSWP=10;
%TOL is the tolerance in residual for the local problem GMRES solver.
rmin=1;
if ((nargin<7)||(isempty(nswp)))
    nswp=10;
end;
if ((nargin<6)||(isempty(rmax)))
    rmax=1000;
end;
radd=0;
local_solver='gmres';
%local_solver='\';
verb=false;
dim_gmres=30;
nrestart=1;

d=size(a,1);
x=x0;
phx=cell(d,1); %Phi matrices for X^T A X
phy=cell(d,1); %Phi matrices for X^T Y
for swp=1:nswp
%    x0=tt_random(tt_size(x),size(x,1),2);
%     x=tt_add(x,x0);
 %   fprintf('er=%3.2e\tnrm=%3.1e\trel_er=%3.2e\n',er,nrm,er/nrm);
%Sweep starts from right-to-left orthogonalization of x
%Compute right-to-left qr and phi matrices
mat=x{d};
[q,rv]=qr(mat,0);
x{d}=q;
%A(n,m,ra))*x(m,rxm)*x(n,rxn1) -> phx(ra,rxm,rxn)
%y(m,ry)*x(m,rx) -> phy(ry,rx)
core=a{d}; n=size(core,1); m=size(core,2); ra=size(core,3);
mat_x=x{d}; rx=size(mat_x,2);
mat_y=y{d};
phy{d}=mat_y'*mat_x;
core=permute(core,[1,3,2]); 
core=reshape(core,[n*ra,m]);
core=core*mat_x; %is n*ra*rx1
core=reshape(core,[n,ra,rx]); %n*ra*rxm
core=permute(core,[2,3,1]); %ra*rxm*n
core=reshape(core,[ra*rx,n]);
phx{d}=core*mat_x; % ra*rxm*rxn
phx{d}=reshape(phx{d},[ra,rx,rx]);

%Back reorthogonalization
for i=(d-1):-1:2 
    core=x{i};
    core=ten_conv(core,3,rv');
    ncur=size(core,1);
    r2=size(core,2);
    r3=size(core,3);
    core=permute(core,[1,3,2]);
    core=reshape(core,[ncur*r3,r2]);
    [x{i},rv]=qr(core,0);
    rnew=min(r2,ncur*r3);
    x{i}=reshape(x{i},[ncur,r3,rnew]);
    x{i}=permute(x{i},[1,3,2]);
    %A(n,m,ra1,ra2)*x(m,rxm1,rxm2)*x(n,rxn1,rxn2)*phx(ra2,rxm2,rxn2)->
    %phx(ra1,rxm1,rxn1)
    %Decipher sizes
    core=a{i}; n=size(core,1); m=size(core,2); ra1=size(core,3); ra2=size(core,4);
    core_x=x{i}; 
    rx3=size(core_x,2); rx1=rx3; rx4=size(core_x,3); rx2=rx4;
    ph=phx{i+1};
    core_x=reshape(core_x,[n*rx3,rx4]); 
    ph=reshape(ph,[ra2*rx2,rx4]);
    ph=core_x*ph'; %ph is n*rx3*ra2*rx2
    ph=reshape(ph,[n,rx3,ra2,rx2]);
    %A(n,m,ra1,ra2)*ph(n,rx3,ra2,rx2) over (n,ra2)
    core=permute(core,[2,3,1,4]); core=reshape(core,[m*ra1,n*ra2]);
    ph=permute(ph,[1,3,2,4]); ph=reshape(ph,[n*ra2,rx3*rx2]);
    ph=core*ph; %ph is m*ra1*rx3*rx2, convolve with x(m,rx1,rx2)
    ph=reshape(ph,[m,ra1,rx3,rx2]); 
    ph=permute(ph,[2,3,1,4]);
    ph=reshape(ph,[ra1*rx3,m*rx2]);
    core_x=permute(x{i},[2,1,3]); 
    core_x=reshape(core_x,[rx1,m*rx2]);
    ph=ph*core_x'; %ph is ra1*rx3*rx1
    ph=reshape(ph,[ra1,rx3,rx1]);
    ph=permute(ph,[1,3,2]); 
    phx{i}=ph;
    %x(n,rx3,rx4)*y(n,ry3,ry4)*phy(ry4,rx4)
    ph=phy{i+1};
    core_y=y{i}; ry3=size(core_y,2); ry4=size(core_y,3);
    core_x=x{i};
    ph=reshape(core_y,[n*ry3,ry4])*ph;
    ph=reshape(ph,[n,ry3,rx4]);
    ph=permute(ph,[1,3,2]); 
    ph=reshape(ph,[n*rx4,ry3]);
    core_x=permute(core_x,[1,3,2]); core_x=reshape(core_x,[n*rx4,rx3]);
    ph=ph'*core_x; ph=reshape(ph,[ry3,rx3]);
    phy{i}=ph;
   
end

%Now start main dmrg iteration
%First, the first core
%A1(n1,m1,ra1)*A2(n2,m2,ra1,ra2)*phx(ra2,rxm2,rxn2)  --- 
%matrix of size B(rxn2*n1n2,m1m2*rxm2)
%Rigth hand size Y1(n1,ry1)*Y2(n2,ry1,ry2)*phy(ry2,rxn2) -> Y(rxn2*n1n2)
%Unknown: X1(m1,rx1)*X2(m2,rx1,rx2) -> m1*m2*rxm2
%Decipher sizes
a1=a{1}; n1=size(a1,1); m1=size(a1,2); ra1=size(a1,3);
a2=a{2}; n2=size(a2,1); m2=size(a2,2); ra2=size(a2,4);
phx2=phx{3};
rxm2=size(phx2,2); 
rxn2=size(phx2,3);
y1=y{1}; ry1=size(y1,2); 
y2=y{2}; ry2=size(y2,3);
phy2=phy{3};
a1=reshape(a1,[n1*m1,ra1]);
a2=permute(a2,[3,1,2,4]);
a2=reshape(a2,[ra1,n2*m2*ra2]);
b=a1*a2;
b=reshape(b,[n1*m1*n2*m2,ra2]);
phx2=reshape(phx2,[ra2,rxm2*rxn2]);
b=b*phx2;
b=reshape(b,[n1,m1,n2,m2,rxm2,rxn2]);
b=permute(b,[1,3,6,2,4,5]);
b=reshape(b,[n1*n2*rxn2,m1*m2*rxm2]);
y2=permute(y2,[2,1,3]);
y2=reshape(y2,[ry1,n2*ry2]);
rhs=y1*y2; 
%rhs is n1*n2*ry2
rhs=reshape(rhs,[n1*n2,ry2]);
rhs=rhs*phy2;
rhs=reshape(rhs,[n1*n2*rxn2,1]);


%sol= b \ rhs;
 sol = pinv(b)*rhs;

%sol=gmres(b,rhs,10,1e-6,1000);



%tt_dist2(tt_mv(a,x),y)
%sol is m1*m2*rxm2
sol=reshape(sol,[m1,m2*rxm2]);
[u,s,v]=svd(sol,'econ');
sol = reshape(sol, m1*m2*rxm2, 1);
res_true = norm(b*sol-rhs)/norm(rhs);
s=diag(s);
% nrm=norm(s);
% rold=size(x{1},2);
% r=my_chop2(s,eps*nrm);
% r=max([rmin,r,rold+radd]);
% r=min(r,rmax);
% r=min(r,size(s,1));

  for r=1:size(s,1)
      sol = reshape(u(:,1:r)*diag(s(1:r))*(v(:,1:r))', m1*m2*rxm2, 1);
      resid = norm(b*sol-rhs)/norm(rhs);
      if (resid<res_true*2)
          break;
      end;
  end;

if ( verb ) 
 fprintf('We can push rank %d to %d \n',1,r);
end
u=u(:,1:r);
x{1}=u;
 v=v(:,1:r)*diag(s(1:r));
 v=reshape(v,[m2,rxm2,r]);
 v=permute(v,[1,3,2]);
 x{2}=v;
 %keyboard;
%Recalculate phx{1},phy{1};
%A(n,m,ra)*X(m,rxm)*X(n,rxn)-> phx(rxm,rxn,ra)
%Y(n,ry)*X(n,rxn) -> phy(rxn,ry)
%Decipher sizes
core=a{1}; n=size(core,1); m=size(core,2); ra=size(core,3);
matx=x{1}; rxm=size(matx,2); rxn=size(matx,2);
maty=y{1}; ry=size(maty,2);
core=reshape(core,[n,m*ra]);
ph=matx'*core; %ph is rxn*m*ra
ph=reshape(ph,[rxn,m,ra]);
ph=permute(ph,[2,1,3]);
ph=reshape(ph,[m,rxn*ra]);
ph=matx'*ph;
phx{1}=reshape(ph,[rxm,rxn,ra]);
phy{1}=matx'*maty;

for i=2:d-2
 %For main iteration:
 %ph1(rxm1,rxn1,ra1)*A1(n1,m1,ra1,ra2)*A2(n2,m2,ra2,ra3)*ph2(ra3,rxm3,rxn3)
 %is a matrix of size (rxn1*rxn2) n1n2 m1m2 (rxm1*rxm3)
 %right-hand side:
 %phy1(rxn1,ry1)*Y1(n1,ry1,ry2)*Y2(n2,ry2,ry3)*phy2(ry3,rxn3)
 %has size rxn1*n1n2*rxn3
 
 %Decipher sizes
 a1=a{i}; n1=size(a1,1); m1=size(a1,2); ra1=size(a1,3); ra2=size(a1,4);
 a2=a{i+1}; n2=size(a2,1); m2=size(a2,2); ra3=size(a2,4);
 %Form right hand side
 y1=y{i}; ry1=size(y1,2); ry2=size(y1,3); 
 y2=y{i+1}; ry3=size(y2,3);
 ph1=phx{i-1}; rxn1=size(ph1,2);
 ph3=phx{i+2}; rxn3=size(ph3,3); 
 ph1=phy{i-1}; ph3=phy{i+2};
 y1=permute(y1,[2,1,3]); y1=reshape(y1,[ry1,n1*ry2]);
 ph1=ph1*y1; %ph1 is rxn1*n1*ry2
 ph1=reshape(ph1,[rxn1*n1,ry2]);
 y2=permute(y2,[2,1,3]); y2=reshape(y2,[ry2,n2*ry3]);
 ph1=ph1*y2; %ph1 is rxn1*n1*n2*ry3
 ph1=reshape(ph1,[rxn1*n1*n2,ry3]);
 rhs=ph1*ph3; 
 rhs=reshape(rhs,[rxn1*n1*n2*rxn3,1]);
 
 % Form matrix
 ph1=phx{i-1}; rxm1=size(ph1,1); rxn1=size(ph1,2);
 ph3=phx{i+2}; rxm3=size(ph3,2); rxn3=size(ph3,3);
%  a1=permute(a1,[3,1,2,4]); a1=reshape(a1,[ra1,n1*m1*ra2]);
 ph1=reshape(ph1,[rxm1*rxn1,ra1]);
%  ph1=ph1*a1; %ph1 is rxm1*rxn1*n1*m1*ra2;
 ph_save=ph1*reshape(permute(a1, [3,1,2,4]), [ra1,n1*m1*ra2]);
%  ph_save=ph1;
 ph3=reshape(ph3,[ra3,rxm3*rxn3]);
  %We had a previous solution:
 %X1(m1,rx1,rx2)*X2(m2,rx2,rx3)
 x1=x{i}; x2=x{i+1}; 
 rx1=size(x1,2); rx2=size(x1,3); rx3=size(x2,3);
 x2=permute(x2,[2,1,3]); x2=reshape(x2,[rx2,m2*rx3]);
 x1=permute(x1,[2,1,3]);
 x1=reshape(x1,[rx1*m1,rx2]);
 sol_prev=x1*x2; 
 sol_prev=reshape(sol_prev,[rxm1*m1*m2*rxm3,1]);
 

 if (strcmp(local_solver,'\'))
     a2=permute(a2,[3,1,2,4]); a2=reshape(a2,[ra2*n2*m2,ra3]);
     ph3=a2*ph3; %ph3 is ra2*n2*m2*rxm3*rxn3
     ph1=reshape(ph_save,[rxm1*rxn1*n1*m1,ra2]);
     ph3=reshape(ph3,[ra2,n2*m2*rxm3*rxn3]);
     b=ph1*ph3;
     %b is rxm1*rxn1*n1*m1*n2*m2*rxm3*rxn3
     b=reshape(b,[rxm1,rxn1,n1,m1,n2,m2,rxm3,rxn3]);
     % is (rxn1*rxn3)*n1n2m1m2 (rxm1 rxm3)
     b=permute(b,[2,3,5,8,1,4,6,7]);
     b=reshape(b,[rxn1*n1*n2*rxn3,rxm1*m1*m2*rxm3]);
    
     
     
%      b1=reshape(inv(b),rxn1*n1,n2*rxn3,rxm1*m1,m2*rxm3); 
%      q1=size(b1,1); q2=size(b1,2); q3=size(b1,3); q4=size(b1,4);
%      b1=permute(b1,[1,3,2,4]); b1=reshape(b1,[q1*q3,q2*q4]);
%      %[pv,indpv]=max(abs(b1(:))); [ipv,jpv]=ind2sub(size(b1),indpv);
%      %u1=b1(:,jpv)/b1(ipv,jpv); v1=b1(ipv,:); v1=v1';
%      ss=svd(b1); 
%      %r0=my_chop2(ss,1e-2*norm(ss));
%      
%      [u1,s1,v1]=svd(b1,'econ'); ss=diag(s1); r0=my_chop2(ss,1e-2*norm(ss)); u1=u1(:,1:r0); s1=s1(1:r0,1:r0); v1=v1(:,1:r0); %u1=u1*s1; 
%      bprec=u1*s1*v1'; bprec=reshape(bprec,[q1,q3,q2,q4]); bprec=permute(bprec,[1,3,2,4]);
%      bprec=reshape(bprec,size(b));
%      %up1=reshape(u1,[q1,q3]); vp1=reshape(v1,[q2,q4]);
%      %bprec=kron(vp1,up1);
%      %norm(b-bprec)/norm(b)
% %     pause
%      fprintf('cond(b)=%3.2e prec=%3.2e size(b)=%dx%d rank=%d \n',cond(b),cond(b*bprec),size(b,1),size(b,2),r0);
%      keyboard;    
     sol = b \ rhs;
     %sol=pinv(b,eps) * rhs;
     %db=diag(diag(b)); tau=0.5;
     %c=b+tau*db;
     %sol=(c) \ (rhs + tau*db*sol_prev);
     %cond(c)
 end;
 
 if (strcmp(local_solver,'\'))
     res_prev = norm(b*sol_prev-rhs)/norm(rhs);
 end;
 
if (strcmp(local_solver, 'gmres')) 
 res_prev=norm(bfun1(sol_prev,a1,a2,ph1,ph3,n1,m1,n2,m2,ra1,ra2,ra3,rxn1,rxm1,rxn3,rxm3)-rhs)/norm(rhs);
 %sol = b \ rhs; 
 %keyboard;
 %Compute block-diagonal preconditioner
%  b1=zeros(size(b));
%  nb1=rxm1*m1;
%  sb1=m2*rxm3;
 %for q=1:nb1
 %    ind=(q-1)*sb1+1:q*sb1;
 %   b1(ind,ind)=inv(b(ind,ind));
 %end
% b1=diag(b);
% b1=1.0/b1;
 %b1=diag(sparse(b1));
 %sol_prev=reshape(sol_prev,[rx1*m1*m2*rx3,1]);
%  sol = pinv(b)*rhs;
%  size(b)
%  [sol_acc,FLAG,RELRES,ITER,RESVEC]=gmres(b,rhs,10,1e-6,100,[],[],sol_prev);
% sol_acc = b \ rhs;
%N1=rxn1*n1; N2=n2*rxn3; M1=rxm1*m1; M2=m2*rxm3;
 %bprec=reshape(b,[rxn1*n1,n2*rxn3,rxm1*m1,m2*rxm3]);
 %bprec=permute(bprec,[1,3,2,4]); bprec=reshape(bprec,[N1*M1,N2*M2]);
 %[u1,s1,v1]=svd(bprec,'econ'); u1=u1(:,1); s1=s1(1,1); v1=v1(:,1);
 %u1=reshape(u1,N1,M1); v1=reshape(v1,N2,M2); u1=u1*s1;
 %u1=inv(u1); v1=inv(v1); bprec=kron(u1,v1);
 bprec=[];
%  fprintf('swp=%d,norm_res=%g\n',i,norm(bfun1(sol_prev,a1,a2,ph1,ph3,n1,m1
%  ,n2,m2,ra1,ra2,ra3,rxn1,rxm1,rxn3,rxm3)-rhs)/norm(rhs));
%  [sol_acc,flag,relres] = gmres(@(vec)bfun1(vec,a1,a2,ph1,ph3,n1,m1,n2,m2,ra1,ra2,ra3,rxn1,rxm1,rxn3,rxm3),rhs,dim_gmres,tol,nrestart,bprec,[],sol_prev);
  [sol_acc] = gmres(@(vec)bfun1(vec,a1,a2,ph1,ph3,n1,m1,n2,m2,ra1,ra2,ra3,rxn1,rxm1,rxn3,rxm3),rhs,dim_gmres,tol,nrestart,bprec,[],sol_prev);

%  sol_acc = gmres(b,rhs,50,eps,100,bprec,[],sol_prev);
%  eps_loc=norm(b*sol_acc-rhs)/norm(rhs); eps_loc=min(eps_loc,1e-3);
 sol=sol_acc;
 %keyboard;
 %sol_acc = qmr(b,rhs,1e-7,10,[],[],sol_prev);
 %sol=sol_acc;
 %sol=
 %norm(sol(:)-sol_prev(:))
 %sol=gmres(b,rhs,10,1e-6,100);
 end;
 
 
 
 %sol is rxm1*m1*m2*rxm3
 sol=reshape(sol,[rxm1*m1,m2*rxm3]);
 [u,s,v]=svd(sol,'econ');
 sol = u*s*v';
  sol=reshape(sol,[rxm1*m1*m2*rxm3, 1]);
  if (strcmp(local_solver,'gmres'))
    res_true = norm(bfun1(sol,a1,a2,ph1,ph3,n1,m1,n2,m2,ra1,ra2,ra3,rxn1,rxm1,rxn3,rxm3)-rhs)/norm(rhs);
  else
    res_true = norm(b*sol-rhs)/norm(rhs);  
  end;
%   fprintf('swp=%d,norm_res2=%g\n',i,res_true);  
   %fprintf('norm=%18f \n',norm(s));
  %fprintf('tensor norm=%3.2e \n',norm(s));
%   rold=size(x{i},3);
 s=diag(s);
 flm=norm(s); %er0=flm.^2; 
 r0=my_chop2(s,eps*flm);
 r0=min(r0, rmax);
  %for r=r0:min(size(s,1), rmax)
  for r=1:min(size(s,1), rmax)
 
      er0=norm(s(r+1:numel(s)));
      sol = u(:,1:r)*diag(s(1:r))*(v(:,1:r))';
      sol = reshape(sol, rxm1*m1*m2*rxm3, 1);
      %sol=u(:,1:r)*s(1:r,1:r)*v(:,1:r)';
      %fprintf('er=%3.2e r=%d \n',norm(sol(:)-sol_acc(:)),r);
      if (strcmp(local_solver,'gmres'))
          resid = norm(bfun1(sol,a1,a2,ph1,ph3,n1,m1,n2,m2,ra1,ra2,ra3,rxn1,rxm1,rxn3,rxm3)-rhs)/norm(rhs);
      else
          resid = norm(b*sol-rhs)/norm(rhs);  
      end;
      if ( verb )
      fprintf('sweep %d, block %d, r=%d, resid=%g, er0=%g\n', swp, i, r, resid, er0/flm);
      end
    %  if (resid<res_true*2 && resid < 2*res_prev )   % && er0 < eps*flm 
     if (resid< 2*res_true )   
    %if ((resid<max(res_true*2, eps)) && (er0<eps*flm))     
          break;
      end;
    %  er0=er0-s(r,r).^2;
  end;
  format long;
  %s=diag(s)
%   res_prev
  %res_true
  %    resid = norm(bfun1(sol,a1,a2,ph1,ph3,n1,m1,n2,m2,ra1,ra2,ra3,rxn1,rxm1,rxn3,rxm3)-rhs)/norm(rhs);

  %resid
  %r
%   s
%   r
%   resid
%   res_prev
  format short;
  % pause
 
  %if ( r == size(s,1))
%   r=max([r,rmin,rold+radd]);
%   r=min(r,rmax);
%   r=min(r,size(s,1));
  %if ( 
  if ( verb )
  fprintf('We can push rank %d to %d \n',i,r);
  end
  u=u(:,1:r);
  v=v(:,1:r)*diag(s(1:r));
  u=reshape(u,[rxm1*m1,r]);
  v=reshape(v,[m2*rxm3,r]);
%   sol = u*v';
%   sol = reshape(sol, rxm1*m1*m2*rxm3,1);
%   fprintf('swp=%d,norm_res3=%g\n',i,norm(bfun1(sol,a1,a2,ph1,ph3,n1,m1,n2,m2,ra1,ra2,ra3,rxn1,rxm1,rxn3,rxm3)-rhs)/norm(rhs));  
  
  u=reshape(u,[rxm1,m1,r]);
  x{i}=permute(u,[2,1,3]);
  %Recompute phx and phy
  %phx(rxm2,rxn2,ra2) =
  %ph1(rxm1,rxn1,ra1)*A1(n1,m1,ra1,ra2)
  %X(m1,rxm1,rxm2)*X(n1,rxn1,rxn2) -> ph(rxm2,rxn2,ra2)
  %ph_save is rxm1*rxn1*n1*m1,ra2
  ph_save=reshape(ph_save,[rxm1,rxn1,n1,m1,ra2]);
  x1=x{i};
  rxm2=size(x1,3);
  ph_save=permute(ph_save,[4,1,2,3,5]);
  ph_save=reshape(ph_save,[m1*rxm1,rxn1*n1*ra2]);
  x1=reshape(x1,[m1*rxm1,rxm2]);
  ph_save=x1'*ph_save;
  %ph_save is rxm2*rxn1*n1*ra2
  ph_save=reshape(ph_save,[rxm2,rxn1,n1,ra2]);
  ph_save=permute(ph_save,[1,4,3,2]); 
  ph_save=reshape(ph_save,[rxm2*ra2,n1*rxn1]);
  x1=x{i}; rxn2=size(x1,3); x1=reshape(x1,[n1*rxn1,rxn2]);
  ph_save=ph_save*x1; 
  %ph_save is rxm2*ra2*rxn2
  ph_save=reshape(ph_save,[rxm2,ra2,rxn2]);
  ph_save=permute(ph_save,[1,3,2]);
  phx{i}=ph_save;
  %phy(rxn1,ry1)*X(n1,rxn1,rxn2)*Y(n1,ry1,ry2)-> phy(rxn2,ry2)
  ph=phy{i-1}; 
  y1=y{i}; ry1=size(y1,2); ry2=size(y1,3);
  x1=x{i};
  y1=permute(y1,[2,1,3]); 
  y1=reshape(y1,[ry1,n1*ry2]);
  ph=ph*y1; %ph is rxn1*n1*ry2
  x1=permute(x1,[2,1,3]); 
  x1=reshape(x1,[rxn1*n1,rxn2]);
  ph=reshape(ph,[rxn1*n1,ry2]); 
  ph=x1'*ph; 
  phy{i}=ph;
%   v=v(:,1:r)*diag(s(1:r));
  v=reshape(v,[m2,rxm3,r]);
  v=permute(v,[1,3,2]);
  x{i+1}=v;
 % tt_dist2(tt_mv(a,x),y)
 % tt_dist2(tt_mv(a,x0),y)
 % keyboard;
end
  

  %And compute the last core 
  %ph1(rxm1,rxn1,ra1)*a1(n1,m1,ra1,ra2)*a2(n2,m2,ra2)
  %Decipher sizes
  a1=a{d-1}; n1=size(a1,1); m1=size(a1,2); ra1=size(a1,3); ra2=size(a1,4);
  a2=a{d}; n2=size(a2,1); m2=size(a2,2);
  ph1=phx{d-2}; 
  rxm1=size(ph1,1); rxn1=size(ph1,2);
  a1=permute(a1,[3,1,2,4]); a1=reshape(a1,[ra1,n1*m1*ra2]);
  ph1=reshape(ph1,[rxm1*rxn1,ra1]);
  ph1=ph1*a1; %ph1 is rxm1*rxn1*n1*m1*ra2
  ph1=reshape(ph1,[rxm1*rxn1*n1*m1,ra2]);
  a2=permute(a2,[3,1,2]); a2=reshape(a2,[ra2,n2*m2]);
  ph1=ph1*a2; 
  %ph1 is rxm1*rxn1*n1*m1*n2*m2
  ph1=reshape(ph1,[rxm1,rxn1,n1,m1,n2,m2]);
  ph1=permute(ph1,[3,5,2,4,6,1]);
  b=reshape(ph1,[n1*n2*rxn1,m1*m2*rxm1]);
  %Compute rhs
  y1=y{d-1}; ry1=size(y1,2); ry2=size(y1,3);
  y2=y{d};
  ph=phy{d-2}; 
  %phy(rxn1,ry1)*y1(n1,ry1,ry2)*y2(n2,ry2)
  y1=permute(y1,[2,1,3]); y1=reshape(y1,[ry1,n1*ry2]);
  ph=ph*y1; %ph is rxn1*n1*ry2
  ph=reshape(ph,[rxn1*n1,ry2]); 
  rhs=ph*y2';
  rhs=reshape(rhs,[rxn1,n1,n2]);
  rhs=permute(rhs,[2,3,1]);
  rhs=reshape(rhs,[n1*n2*rxn1,1]);
  %rhs = reshape(rhs,[rxn1*n1*n2,1]);
  
  
%   sol = b \ rhs;
 sol = pinv(b)*rhs;
  
  %sol=gmres(b,rhs,10,1e-6,1000);

  
  
  %sol is m1*m2*rxm1
  sol=reshape(sol,[m1,m2,rxm1]);
  sol=permute(sol,[1,3,2]);
  sol=reshape(sol,[m1*rxm1,m2]);
  [u,s,v]=svd(sol,'econ');
  sol = reshape(sol, m1, rxm1, m2);
  sol = permute(sol, [1 3 2]);
  res_true = norm(b*reshape(sol, m1*m2*rxm1, 1)-rhs)/norm(rhs);
  s=diag(s);  
%   rold=size(x{d-1},3);
%   r=my_chop2(s,eps*norm(s));
%   r=max([r,rmin,rold+radd]);
  for r=1:size(s,1)
      sol = u(:,1:r)*diag(s(1:r))*(v(:,1:r))';
      sol = reshape(sol, m1, rxm1, m2);
      sol = permute(sol, [1 3 2]);      
      sol = reshape(sol, m1*m2*rxm1, 1);
      resid = norm(b*sol-rhs)/norm(rhs);
      if (resid<res_true*2)
          break;
      end;
  end;  
  r=min(r,rmax);
  r=min(r,size(s,1));  
  %if ( 
  if ( verb )
  fprintf('We can push rank %d to %d \n',1,r);
  end
  u=u(:,1:r);
  u=reshape(u,[m1,rxm1,r]);
  x{d-1}=u;
  v=v(:,1:r)*diag(s(1:r));
  x{d}=v;
 
end

return
end
%fprintf('Last stand \n');
%keyboard;


function [y]=bfun1(x,a1,a2,ph1,ph2,n1,m1,n2,m2,ra1,ra2,ra3,rxn1,rxm1,rxn3,rxm3)
%[Y]=BFUN1(x,a1,a2,ph1,ph2,n1,m1,n2,m2,ra1,ra2,ra3,rxn1,rxm1,rxn2,rxm2)
%This MEGA function computes a single matrix-by-vector product
%ph1(rxm1,rxn1,ra1)*A1(n1,m1,ra1,ra2)*A2(n2,m2,ra2,ra3)*ph2(ra3,rxm3,rxn3)
%X(rxm1,m1,m2,rxm3)

y=reshape(ph1,[rxm1,rxn1*ra1]);
x=reshape(x,[rxm1,m1*m2*rxm3]);
y=y'*x; %Is rxn1*ra1*m1*m2*rxm3
%Convolve over m1,ra1
a1=permute(a1,[2,3,1,4]); %is [m1*ra1,n1*ra2]);
y=reshape(y,[rxn1,ra1,m1,m2,rxm3]);
y=permute(y,[3,2,1,4,5]);
y=reshape(y,[m1*ra1,rxn1*m2*rxm3]);
a1=reshape(a1,[m1*ra1,n1*ra2]);
y=y'*a1; %is rxn1*m2*rxm3*n1*ra2, over m2*ra2 with a2
y=reshape(y,[rxn1,m2,rxm3,n1,ra2]);
y=permute(y,[1,4,3,2,5]);
y=reshape(y,[rxn1*n1*rxm3,m2*ra2]);
a2=permute(a2,[2,3,1,4]);
a2=reshape(a2,[m2*ra2,n2*ra3]);
y=y*a2; %y is rxn1*n1*rxm3*n2*ra3
y=reshape(y,[rxn1*n1,rxm3,n2,ra3]);
y=permute(y,[1,3,4,2]);
y=reshape(y,[rxn1*n1*n2,ra3*rxm3]);
ph2=reshape(ph2,[ra3*rxm3,rxn3]);
y=y*ph2;
y=reshape(y,[rxn1*n1*n2*rxn3,1]);
return
end