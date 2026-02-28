# This script extracts data from a specified CSV file and plots it

#  Add required functions for analysis
import os
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as plticker
import matplotlib as mpl
import csv
from io import StringIO


#Designate files
Rplus = 'S11_Si_YIG_Co_mult_domain-3-refl.datD'
Rminus = 'S11_Si_YIG_Co_mult_domain-3-refl.datA'


#Name of consolidated file
f = open("S11-YIG-Co-30mT.pnr", "w")

#Extract data as ++ and -- 
Plusdata = np.loadtxt(Rplus)
Q_plus = Plusdata[:,0]
dQ_plus = Plusdata[:,1]
R_plus = Plusdata[:,2]
dR_plus = Plusdata[:,3]
T_plus = Plusdata[:,4]

MinusData = np.loadtxt(Rminus)
Q_minus = MinusData[:,0]
dQ_minus = MinusData[:,1]
R_minus = MinusData[:,2]
dR_minus = MinusData[:,3]
T_minus = MinusData[:,4]


Q_plus = np.array(Q_plus)
dQ_plus = np.array(dQ_plus)
Q_minus = np.array(Q_minus)
R_plus = np.array(R_plus)
dR_plus = np.array(dR_plus)
R_minus = np.array(R_minus)
dR_minus = np.array(dR_minus)
T_plus = np.array(T_plus)
T_minus = np.array(T_minus)

SA = (R_plus - R_minus)/(R_plus + R_minus)
dSA = (np.sqrt(dR_plus**2 + dR_minus**2))/(R_plus + R_minus)
SA_T = (T_plus - T_minus)/(T_plus + T_minus)



N = len(Q_plus)
# print(N)
f.write('Q' + '\t' + 'dQ' + '\t' + 'R++' + '\t' + 'dR++' + '\t' + 'R--' + '\t' + 'dR--' + '\t' + 'T++' + '\t' + 'T--' + '\t' + 'SA' + '\t' 'dSA' +'\t' + 'T SA' + '\n')
f.write('A-1' + '\t' + 'A-1' + '\t' + 'arb. units' + '\t' + 'arb. units' + '\t' + 'arb. units' + '\t' + 'arb. units' + '\t' + 'arb. units' + '\t' + 'arb. units' + '\t' + 'arb. units' + '\t' 'arb. units' +'\t' + 'arb. units' + '\n')
for i in range(0,N):
	f.write(str(Q_plus[i]) + '\t' + str(dQ_plus[i]) + '\t' + str(R_plus[i]) + '\t' + str(dR_plus[i]) + '\t' + str(R_minus[i]) + '\t' + str(dR_minus[i]) + '\t' + str(T_plus[i]) + '\t' + str(T_minus[i]) + '\t' + str(SA[i]) + '\t' + str(dSA[i]) + '\t' + str(SA_T[i]) + '\n')
f.close()