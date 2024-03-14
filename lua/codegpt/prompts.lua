local Prompts = {
    nested = [[*****experience: nested loops*****
//if you see nested loops, there are a few things you should consider.

//nested loops 1
//this loop has 3 layer, and all 3 layers have no data dependency between iterations, thus all 3 layer is parallelizable. In this case, you should parallelize the outer-most parallelizable layer, the i-layer. 
//Don't forget to add private to the loop index which are inside the i-loop, in this case j and k.
//you should pay extra attention to the array variables in the inner loop, like the "h[]" array in this loop, it only contains subscript "k", so if you parallelize the outer-most loop, the h[k] might be access at the same time by different threads, for example thread1: i=1,j=1,k=5,thread2:i=4;j=2,k=5. thread 1 and 2 are accessing h[5] at the same time, so you need to use reduction to avoid data race.
#pragma omp parallel for private(j, k) reduction(+: h[:N])
for(i = 0; i < N; i++) {
    for(j = 0; j < N; j++) {
        for(k = 0; k < N; k++) {
            a = b + x;
            h[k] = h[k] + i;
        }
    }
}

//nested loops 2
//In this case the outer loop has no dependency, but the inner loop has, so just parallelize the outer loop will be fine.
#pragma omp parallel for private(j)
for(i = 0; i < N; i++) {
    for(j = 0; j < N; j++) {
    	x[i][j] = x[i][j + 1] + 10;
    }
}
*****experience: nested loops*****
 
 
]],
    private = [[*****experience: private variables*****
//In some cases the variable may need to be set private to thread to avoid data race.
//In a loop, if a variable is first being assigned, then being used, that variable should be set private to thread. 
//private variables example
double result = 0.0;
double step = 0.1;
double xx;
/*
   	1. private(xx) is used here because in the first line xx is assigned to a value. Then, xx is used in "a = xx + yy + b", so private(xx) is a must. 
    2. there is no private(yy) here because if a variable is declared inside the loop, it is already privte to each threads, you should not privatize it again, it will cause error
*/
#pragma omp parallel for private(xx)
for(i = 0; i < num_steps; i++)
{
    double yy;
    yy = m + n;
    xx = (i + 0.5) * step;
    a = xx + yy + b;
}
*****experience: private variables*****
 
 
]],
    dependency = [[*****experience: dependency between iterations*****
//dependency example
int array[100];
int i, j, k;
//this loop can't be parallelized as there is dependency between iterations
for(i = 0; i < N; i++){
    array[i] = array[i] + array[i + 1];
}
*****experience: dependency between iterations*****
 
 
]],
    conditional = [[*****experience: conditional expression*****
//conditional expression example
int max = 0;
#pragma omp parallel for
for(int i = 0; i < N; i++)
{
    #pragma omp atomic compare
    max = max < a[i] ? a[i] : max;
}
*****experience: conditional expression*****
 
 
]],
    reduction = [[*****experience: reduction*****
//reduction example
int sum_1 = 0;
int sum_2 = 0;
#pragma omp parallel for reduction(+: sum_1) reduction(*: sum_2)
for(i = 0; i < N; i++)
{
    sum_1 = sum_1 + i;
    sum_2 *= i;
}
*****experience: reduction*****
 
 
]],
    iter = [[*****experience: too few iterations*****
//When you receive a loop, the first thing you do is to calculate how many iterations it have, if the number is less than 50, do not parallelize the loop.
//And no matter what is inside this loop, you should not parallelize it, like this loop, it has a 1000000 iteration subloop, but if you parallelize the outer one, the threads(assuming 16) are still not going to be fully utilized
//Outer loop has only 10 iterations, do not parallelize! Try to parallelize the inner loop instead!
for(i = 0; i < 5; i++)
{   
    #pragma omp parallel for
    for(j = 0; j < 1000000; j++)
    {
    	//some compute task
    }
}

//If the iteration count is unknown, like in the following loop, you can assume the iteration count is enough.
#pragma omp parallel for
for(i = 0; i < Na; i++)
{
    a[i] = i;
}
*****experience: too few iterations*****
 
 
]],
    update = [[*****experience: update expression*****
//If you see an update expression, you can parallelize it using reduction
#pragma omp parallel for reduction(+:a) reduction(-:b)
for(i = 0; i < N; i++)
{   
    a++;
    b--;
}

*****experience: update expression*****
 
 
]],
}

return Prompts
