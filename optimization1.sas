PROC IMPORT OUT=stockdata 
            DATAFILE= "/home/u63347966/sasuser.v94/Final project
/Final_optimization_bac_msft_student.xlsx"
            DBMS=XLSX REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
RUN;

data stockdata1;
set stockdata;
rename "BAC_Adj Close"n=bac_adj_close;
rename "MSFT_Adj Close"n=msft_adj_close;
run;

proc sort data=stockdata1;
by date;
run;

data stockdata1;
set stockdata1;
ret1=bac_adj_close/lag(bac_adj_close)-1;
ret2=msft_adj_close/lag(msft_adj_close)-1;
run;

/*matrix*/
ods select Cov PearsonCorr;
proc corr data=work.stockdata1 noprob outp=OutCorr /** store results **/
          nomiss /** listwise deletion of missing values **/
          cov;   /**  include covariances **/
var ret1 ret2;
run;

/*given the target rate of return, min the portfolio risk*/
proc optmodel;
   /* let x1, x2,... be the weight invested in each asset 
   1..n: n assets
   coeff is the COVARIANCE matrix
   r is the return vector
   */
   var x{1..2};						
   num covariancem{1..2, 1..2} = [
0.0003831780	0.0001039719
0.0001039719	0.0001837790                            
                            ];                  
    num r{1..2}=[0.0036556352 0.0060277551];
  
     /* minimize the variance of the portfolio's total return */
   minimize f = sum{i in 1..2, j in 1..2}covariancem[i,j]*x[i]*x[j];

   /* subject to the following constraints */
   con weights: sum{i in 1..2}x[i] =1;/*x1+x2+...+xn=1*/
   con targetr: sum{i in 1..2}r[i]*x[i] =0.005;/*the target return is your choice.
   it's better to choose a reasonable number for the target return,eg, in the range;
   slightly bigger than the max; slightly smaller than the min*/

   solve with qp;

   /* print the optimal solution */
   print x;
quit;

/*min variance portfolio*/
 proc optmodel;
   /* let x1, x2,... be the weight invested in each asset 
   1..n: n assets
   coeff is the COVARIANCE matrix
   r is the return vector
   */
   var x{1..2};						
   num covariancem{1..2, 1..2} = [
0.0003831780	0.0001039719
0.0001039719	0.0001837790                            
                            ];                  
    num r{1..2}=[0.0036556352 0.0060277551];
  
     /* minimize the variance of the portfolio's total return */
   minimize f = sum{i in 1..2, j in 1..2}covariancem[i,j]*x[i]*x[j];

   /* subject to the following constraints */
   con weights: sum{i in 1..2}x[i] =1;/*x1+x2+...+xn=1*/
   solve with qp;
   /* print the optimal solution */
   print x;
quit;

proc import 
out = ff
datafile = "/home/u63347966/sasuser.v94/F-F_Research_Data_Factors_daily.CSV"
dbms = csv replace;
getnames = yes;
datarow = 2;
run;

DATA work.ff1;
  SET work.ff;
  rename var1=date;
  rename 'Mkt-RF'n=mkt_rf;   /*it depends on the variable name in the data*/
  DATE1 = INPUT(PUT(var1,8.),YYMMDD8.);
  FORMAT DATE1 YYMMDD10.;
  year=year(date1);
run;

DATA work.ff1;/*ff data is quoted in Basis points (BPS)*/
  SET work.ff1;
  mkt_rf_d=mkt_rf/100;
  smb_d=smb/100;
  hml_d=hml/100;
  rf_d=rf/100;
RUN;

data stock_for_reg;
set stockdata1;
new_date = input(put(date, mmddyy10.),mmddyy10.);
format new_date yymmdd10.;
run;

proc sort data = ff1;
by date1;
run;

proc sort data = stock_for_reg;
by new_date;
run;

proc sql;
create table stock_ff_reg as
select *
from stock_for_reg s, ff1 f
where s.new_date = f.date1;
quit;

data stock_ff_reg1;
set stock_ff_reg;
rp = ret2 - rf_d;
run;

proc reg data=stock_ff_reg1;
ff_3factor: model rp = mkt_rf_d smb_d hml_d;
run;