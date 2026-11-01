#!/usr/bin/env python3
"""Development-only independent references. No Python dependency is bundled in VAPULA.

Reproduce with SciPy 1.18.1 and NumPy 2.5.4. The seed and formulas for the
ancillary confidence intervals/effect sizes are explicit below.
"""
import json
from pathlib import Path
import numpy as np
import scipy
from scipy import stats

ROOT = Path(__file__).resolve().parents[1]
rng = np.random.default_rng(20261030)

one_sample = []
for i in range(18):
    n = [2, 3, 8, 25, 100, 1000][i % 6]
    values = rng.normal([0, 3.5, -4][i % 3], [0.2, 1, 12][i % 3], n)
    reference = [-1.0, 0.0, 2.5][i % 3]
    alpha = [0.01, 0.05, 0.1][i % 3]
    result = stats.ttest_1samp(values, reference)
    ci = result.confidence_interval(confidence_level=1-alpha)
    sd = float(values.std(ddof=1))
    diff = float(values.mean()-reference)
    one_sample.append(dict(name=f'one-sample-{i}', values=values.tolist(), mean=reference, alpha=alpha,
                           expected=dict(n=n, sample_mean=float(values.mean()), reference_mean=reference,
                                         sample_sd=sd, standard_error=sd/np.sqrt(n), mean_difference=diff,
                                         t=float(result.statistic), df=float(result.df), p_two_sided=float(result.pvalue),
                                         ci_lower=float(ci.low), ci_upper=float(ci.high),
                                         difference_ci_lower=float(ci.low-reference), difference_ci_upper=float(ci.high-reference),
                                         cohen_d=diff/sd)))

paired = []
for i in range(15):
    n = [2, 5, 12, 40, 120][i % 5]
    x = rng.normal(20, 4, n)
    y = x + rng.normal([0, 1.5, -2][i % 3], [0.2, 1, 4][i % 3], n)
    alpha = [0.01, 0.05, 0.1][i % 3]
    result = stats.ttest_rel(x, y)
    ci = result.confidence_interval(confidence_level=1-alpha)
    differences = x-y
    sd = float(differences.std(ddof=1))
    paired.append(dict(name=f'paired-{i}', x=x.tolist(), y=y.tolist(), alpha=alpha,
                       expected=dict(n=n, n_pairs=n, mean_x=float(x.mean()), mean_y=float(y.mean()),
                                     mean_difference=float(differences.mean()), difference_sd=sd,
                                     standard_error=sd/np.sqrt(n), t=float(result.statistic),df=float(result.df),
                                     p_two_sided=float(result.pvalue),ci_lower=float(ci.low),ci_upper=float(ci.high),
                                     difference_ci_lower=float(ci.low),difference_ci_upper=float(ci.high),
                                     cohen_d_z=float(differences.mean()/sd))))

anova = []
for i in range(16):
    k = [2, 3, 4, 6][i % 4]
    groups = [rng.normal(3+j*[0, 0.5, 3, 10][i % 4], 0.5+(i % 3), 2+j+(i % 5)*3) for j in range(k)]
    if i == 3:
        groups[0] = np.repeat(2.0, len(groups[0]))  # One constant group is permitted.
    result = stats.f_oneway(*groups, equal_var=True)
    values = np.concatenate(groups)
    grand = float(values.mean())
    between = float(sum(len(g)*(g.mean()-grand)**2 for g in groups))
    within = float(sum(np.sum((g-g.mean())**2) for g in groups))
    dfb = k-1
    dfw = len(values)-k
    anova.append(dict(name=f'anova-{i}', groups=[g.tolist() for g in groups],
                      expected=dict(n=len(values), groups=k,grand_mean=grand,f=float(result.statistic),
                                    df_between=dfb,df_within=dfw,ss_between=between,ss_within=within,
                                    ms_between=between/dfb,ms_within=within/dfw,p_value=float(result.pvalue),
                                    eta_squared=between/(between+within))))

mann_whitney=[]
explicit=[([1,2,3],[4,5,6]),([1,2,3],[1,2,3]),([1,1,2],[1,2,3]),([5],[1,2,3]),([0,1],[10,10,10,20]),([1,1],[2,2])]
for i in range(18):
    if i < len(explicit):
        a,b=map(np.asarray,explicit[i])
    else:
        a=rng.normal(0,2,[3,10,50][i%3])
        b=rng.normal([0,1,4][i%3],2,[7,11,100][i%3])
        if i%2==0:
            a=np.round(a);b=np.round(b)
    result=stats.mannwhitneyu(a,b,method='asymptotic',use_continuity=True,alternative='two-sided')
    combined=np.concatenate([a,b]); n=len(combined); na=len(a);nb=len(b)
    _,frequencies=np.unique(combined,return_counts=True)
    tie_term=float(np.sum(frequencies.astype(float)**3-frequencies))
    variance=na*nb/12*((n+1)-tie_term/(n*(n-1)))
    ua=float(result.statistic);ub=na*nb-ua;centered=ua-na*nb/2
    z=np.sign(centered)*max(0,abs(centered)-0.5)/np.sqrt(variance)
    mann_whitney.append(dict(name=f'mann-whitney-{i}',a=a.tolist(),b=b.tolist(),expected=dict(
        n_a=na,n_b=nb,u_a=ua,u_b=ub,z_corrected=float(z),p_two_sided=float(result.pvalue),
        rank_biserial_a_minus_b=2*ua/(na*nb)-1,tie_groups=int(np.sum(frequencies>1)),
        tied_observations=int(np.sum(frequencies[frequencies>1])),continuity_correction=0.5,minimum_group_n=min(na,nb))))

chi_square=[]
matrices=[[[12,3],[4,14]],[[20,20],[20,20]],[[1,0],[0,2]],[[1000000,100],[10,1000000]],
          [[10,20,30],[20,20,20]],[[0,2,7],[9,0,4],[5,8,1]]]
for rows,columns in [(2,4),(3,3),(4,5),(8,8),(20,20),(50,50)]:
    matrices.append(rng.integers(1,40,size=(rows,columns)).tolist())
for i,matrix in enumerate(matrices):
    observed=np.array(matrix,dtype=int)
    result=stats.chi2_contingency(observed,correction=False)
    expected=result.expected_freq
    total=int(observed.sum())
    chi_square.append(dict(name=f'chi-square-{i}',counts=matrix,expected=dict(
        n=total,rows=observed.shape[0],columns=observed.shape[1],chi_square=float(result.statistic),
        df=int(result.dof),p_value=float(result.pvalue),cramers_v=float(np.sqrt(result.statistic/(total*min(np.array(observed.shape)-1)))),
        minimum_expected=float(expected.min()),expected_below_5=int(np.sum(expected<5)),
        expected_below_1=int(np.sum(expected<1)),expected_below_5_fraction=float(np.mean(expected<5)),yates_correction=0)))

payload=dict(generator=f'SciPy {scipy.__version__}; NumPy {np.__version__}; seed 20261030',
             absoluteTolerance=1e-9,relativeTolerance=1e-8,
             oneSample=one_sample,paired=paired,anova=anova,mannWhitney=mann_whitney,chiSquare=chi_square)
assert all(np.isfinite(v) for cases in [one_sample,paired,anova,mann_whitney,chi_square] for case in cases for v in case['expected'].values())
output=ROOT/'Tests/VapulaTests/Fixtures/expanded-statistical-reference.json'
output.write_text(json.dumps(payload,indent=2,allow_nan=False)+'\n')
print(f'Generated {len(one_sample)} one-sample, {len(paired)} paired, {len(anova)} ANOVA, {len(mann_whitney)} Mann-Whitney and {len(chi_square)} chi-square cases.')
