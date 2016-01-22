#######################

##Risk measure

#######################
library(matrixStats)
library(MASS)
library(synthpop)
library(FactoMineR)

##Theory
##setup
rowDiff = function(df, row){
    return(abs(row - df))
}

allClose = function(list, tol, numVar){
    temp = (list < tol)
    return(sum(temp[1:(numVar-1)]))
}

##runit
#synthX[closeInd[2,] == 2,]
#sum((synthX[closeInd[2, ] == 2, 3] - xDat[2, 3]) < 1)/nrow(synthX[closeInd[2, ] == 2,])

computeMSE = function(real, synth, numVar){
    closeness = vector("list", nrow(real))
    for(i in 1:nrow(real)){
        closeness[[i]] = t(apply(synth, 1, rowDiff, row = real[i,]))
    }
    
    closeInd = matrix(NA, nrow = nrow(real), ncol = nrow(synth))
    for(i in 1:nrow(real)){
        closeInd[i,] = apply(closeness[[i]], 1, allClose, tol = sd(real), numVar = numVar)  
    }
    
    MSE = matrix(NA, nrow = nrow(real), ncol = 1)
    for(i in 1:nrow(real)){
        MSE[i,] = var(synth[closeInd[i, ] == (ncol(real) - 1), ncol(real)]) + (mean(synth[closeInd[i, ] == (ncol(real) - 1), 
                                                                                          ncol(real)]) - real[i, ncol(real)])^2    
    }
    
    return(MSE)
}

computeBest = function(real, synth, numVar){
    closeness = vector("list", nrow(real))
    for(i in 1:nrow(real)){
        closeness[[i]] = t(apply(synth, 1, rowDiff, row = real[i,]))
    }
    
    closeInd = matrix(NA, nrow = nrow(real), ncol = nrow(synth))
    for(i in 1:nrow(real)){
        closeInd[i,] = apply(closeness[[i]], 1, allClose, tol = sd(real), numVar = numVar)  
    }
    
    minVal = matrix(NA, nrow = nrow(real), ncol = 1)
    for(i in 1:nrow(real)){
        minInd = which.min(rowMedians(closeness[[i]][, 1:(ncol(real) - 1)]))
        minVal[i,] = abs(synth[minInd, ncol(real)] - real[i, ncol(real)])  
    }
    
    return(minVal)
}


#-------------------------
#simulation study

numSim = 25*4
simulOut = matrix(NA, nrow = numSim, ncol = 7)
colnames(simulOut) = c("PCMSE", "tradMSE", "PCWorst", "tradWorst", "PCUtil", "tradUtil", "numVar")


##real data
numVar = c(5, 20, 50, 190)
numObs = 100
for(h in 1:length(numVar)){
    for(q in 1:numSim/length(numVar)){
        uDat = rnorm(numObs, mean = 5, sd = 3)
        zDat = mvrnorm(n = numObs, mu = rep(0, numVar[h] ), Sigma = diag(2, numVar[h] ))
        xDat = uDat + zDat
        colnames(xDat) = paste("x", 1:numVar[h] , sep = "")
        
        ##synthetic by PC
        synthX = vector("list", 5)
        for(j in 1:5){
            synthU = mean(xDat)
            synthZ = matrix(NA, nrow = numObs, ncol = numVar[h] )
            for(i in 1:numVar[h] ){
                synthZ[, i] = rnorm(numObs, mean = mean(xDat[, i]) - synthU, sd = sd(xDat[, i]))
            }
            synthX[[j]] = synthU + synthZ
            colnames(synthX[[j]]) = paste("x", 1:numVar[h] , sep = "")
        }
        
        ##synthetic by PC actual
        PC = PCA(xDat, scale.unit = F)
        reconDat = reconst(PC, ncp = 1)
        residDat = xDat - reconDat
        
        synSamp = matrix(NA, ncol = 5, nrow = numObs)
        bootResid = vector("list", 5)
        secondSamp = matrix(NA, ncol = 5, nrow = numObs)
        secondResid = vector("list", 5)
        synDat = vector("list", 5)
        
        for(i in 1:5){
            synSamp[, i] = sample(1:numObs, 100, replace = T)
            secondSamp[, i] = sample(1:numObs, 100, replace = T)
            
            bootResid[[i]] = matrix(NA, ncol = numVar[h], nrow = numObs)
            secondResid[[i]] = matrix(NA, ncol = numVar[h], nrow = numObs)
            for(j in 1:numObs){
                bootResid[[i]][j, ] = residDat[synSamp[j,i], ] 
                secondResid[[i]][j, ] = residDat[secondSamp[j,i], ] 
            }
            
            temp = reconDat + bootResid[[i]]
            tempPC = PCA(temp, scale.unit = F)
            tempRecon = reconst(tempPC, ncp = 1)
            
            synDat[[i]] = tempRecon + secondResid[[i]]
            colnames(synDat[[i]]) = paste("x", 1:numVar[h] , sep = "")
            
        }
        
        ##synthetic by traditional
        tradSyn = syn(xDat, m = 5, method = "parametric")
        
        ##Risk - MSE
        synthXC = rbind(synthX[[1]], synthX[[2]], synthX[[3]], synthX[[4]], synthX[[5]])
        tradC = rbind(tradSyn$syn[[1]], tradSyn$syn[[2]], tradSyn$syn[[3]], tradSyn$syn[[4]], tradSyn$syn[[5]])
        synXX = rbind(synDat[[1]], synDat[[2]], synDat[[3]], synDat[[4]], synDat[[5]])
        
        PCMSE = computeMSE(xDat, synthXC, numVar = numVar[h])
        tradMSE = computeMSE(xDat, tradC, numVar = numVar[h])
        PCAMSE = computeMSE(xDat, synXX, numVar = numVar[h])
        
        simulOut[q + (h-1)*25, "PCMSE"] = median(PCMSE, na.rm = T)
        simulOut[q + (h-1)*25, "tradMSE"] = median(tradMSE, na.rm = T)
        
        ##Risk - Best
        PCBest = computeBest(xDat, synthXC, numVar = numVar[h])
        tradBest = computeBest(xDat, tradC, numVar = numVar[h])
        PCABest = computeBest(xDat, synXX, numVar = numVar[h])
        
        simulOut[q + (h-1)*25, "PCWorst"] = median(PCBest, na.rm = T)
        simulOut[q + (h-1)*25, "tradWorst"] = median(tradBest, na.rm = T)
        
        
        ##Utility - Mean
        pcUtilMSE = apply(synthXC, 2, var) + (colMeans(xDat) - colMeans(synthXC))^2
        tradUtilMSE = apply(tradC, 2, var) + (colMeans(xDat) - colMeans(tradC))^2
        PCAUtilMSE = apply(synXX, 2, var) + (colMeans(xDat) - colMeans(synXX))^2
        
        simulOut[q + (h-1)*25, "PCUtil"] = median(pcUtilMSE, na.rm = T)
        simulOut[q + (h-1)*25, "tradUtil"] = median(tradUtilMSE, na.rm = T)
        
        ##record Var
        simulOut[q + (h-1)*25, "numVar"] = numVar[h]
    } 
}

##Plots
library(ggplot2)
library(grid)
library(reshape2)

tempDat = data.frame(na.omit(simulOut))
plotOut = data.frame(matrix(NA, nrow = 110, ncol = 5))
colnames(plotOut) = c("MSE", "Worst", "Util", "numVar", "type")
plotOut[1:55, "MSE"] = tempDat$PCMSE
plotOut[56:110, "MSE"] = tempDat$tradMSE
plotOut[1:55, "Worst"] = tempDat$PCWorst
plotOut[56:110, "Worst"] = tempDat$tradWorst
plotOut[1:55, "Util"] = tempDat$PCUtil
plotOut[56:110, "Util"] = tempDat$tradUtil
plotOut[1:55, "numVar"] = plotOut[56:110, "numVar"] = tempDat$numVar
plotOut[1:55, "type"] = "PC"
plotOut[56:110, "type"] = "Traditional"
plotOut[1:55, "sample"] = plotOut[56:110, "sample"] = c(1:55)


msePlot = ggplot(data = plotOut, aes(x = sample, y = MSE, colour = type)) + geom_point() + geom_smooth(method = "lm")
worstPlot = ggplot(data = plotOut, aes(x = sample, y = Worst, colour = type)) + geom_point() + geom_smooth(method = "lm")
utilPlot = ggplot(data = plotOut, aes(x = sample, y = Util, colour = type)) + geom_point() + geom_smooth(method = "lm")

grid.newpage()
pushViewport(viewport(layout = grid.layout(2, 1)))
print(msePlot, vp = viewport(layout.pos.row = 1, layout.pos.col = 1) )
print(worstPlot, vp = viewport(layout.pos.row = 2, layout.pos.col = 1) )
print(utilPlot, vp = viewport(layout.pos.row = 3, layout.pos.col = 1) )

utilPlot