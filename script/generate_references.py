#!/usr/bin/env python3
"""Development only. pip install scipy==1.18.1 numpy==2.5.4. Never shipped in the app."""
import json
from pathlib import Path
import numpy as np
import scipy
from scipy import stats
root = Path(__file__).resolve().parents[1]
rng = np.random.default_rng(20261029)
cases = []
for index in range(18):
    n = [3, 4, 7, 15, 25, 100][index % 6]
    x = rng.normal(30, 7, n)
    y = 2 + 0.4*x + rng.normal(0, 4, n)
    if index % 3 == 0:
        x = np.round(x / 4)
        y = np.round(y / 3)
    if np.ptp(x) == 0: x[0] += 1
    if np.ptp(y) == 0: y[0] += 1
    q = np.quantile(x, [.25, .5, .75], method='linear')
    reg = stats.linregress(x, y)
    prediction = reg.intercept + reg.slope * x
    cases.append(dict(name=f'paired-{index}', x=x.tolist(), y=y.tolist(), expected=dict(
        mean=float(x.mean()), sample_variance=float(x.var(ddof=1)), q1=float(q[0]), median=float(q[1]), q3=float(q[2]),
        pearson=float(stats.pearsonr(x,y).statistic), spearman=float(stats.spearmanr(x,y).statistic),
        slope=float(reg.slope), intercept=float(reg.intercept), r_squared=float(reg.rvalue**2),
        residual_ss=float(np.sum((y-prediction)**2)), slope_se=float(reg.stderr))))
welch=[]
for index, (n,m) in enumerate([(2,2),(2,7),(3,4),(10,17),(30,23),(100,55),(7,2),(50,4),(3,100)]):
    a=rng.normal(3, [1,0.1,20][index%3], n)
    b=rng.normal(5, [5,10,0.3][index%3], m)
    alpha=[.01,.05,.1][index%3]
    ref=stats.ttest_ind(a,b,equal_var=False)
    ci=ref.confidence_interval(confidence_level=1-alpha)
    welch.append(dict(a=a.tolist(),b=b.tolist(),alpha=alpha,expected=dict(
        t=float(ref.statistic),df=float(ref.df),p_two_sided=float(ref.pvalue),ci_lower=float(ci.low),ci_upper=float(ci.high),
        difference_a_minus_b=float(a.mean()-b.mean()),cohen_d_av=float((a.mean()-b.mean())/np.sqrt((a.var(ddof=1)+b.var(ddof=1))/2)))))
student=[]
for df in [1,1.5,2,5,10,30,100,1000]:
    for t in [0,.1,1,2,10,100]:
        student.append(dict(df=df,t=t,p=float(2*stats.t.sf(abs(t),df))))
quantiles=[dict(df=df,p=p,value=float(stats.t.ppf(p,df))) for df in [1,1.5,2,5,30,1000] for p in [.95,.975,.995]]
output=dict(generator=f'SciPy {scipy.__version__}; NumPy {np.__version__}; seed 20261029',absoluteTolerance=1e-9,relativeTolerance=1e-8,paired=cases,welch=welch,student=student,quantiles=quantiles)
(root/'Tests/VapulaTests/Fixtures/statistical-reference.json').write_text(json.dumps(output,indent=2)+'\n')
# A deliberately synthetic, nonpersonal demonstration dataset with nulls, duplicates, ties and an extreme value.
lines=['id,grupo,x,y,categoria']
for i in range(1,31):
    x='' if i==7 else str(125 if i==30 else i+3)
    y='' if i==11 else str(round(2.3*i+np.sin(i)*3,3))
    lines.append(f'{i},{"A" if i%2 else "B"},{x},{y},{["uno","dos","tres"][i%3]}')
lines.append(lines[4])
(root/'Tests/VapulaTests/Fixtures/laboratorio.csv').write_text('\n'.join(lines)+'\n')
print(f'Generated {len(cases)} paired, {len(welch)} Welch, {len(student)} Student t, {len(quantiles)} quantile references.')
