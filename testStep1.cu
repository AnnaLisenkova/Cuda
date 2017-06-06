#include <iostream>
#include <cstdlib>
#include <cuda.h>
#include <map>
#include <fstream>

using namespace std;

#define delta                10
#define rows                     500
#define columns                  500


int* findBarrier(int x, int y, int * Map[columns]){
        //y-координаты препятствий
        int *yCoordinates = new int [columns];
        //текущее значение разности м-у двумя точками по вертикали
        int currDelta = 0;

        for(int i = 0; i < columns; i++){
                //рассматриваем область выше параллели, на которой стоит робот
                for(int j = y; j > 0; j--){
                        currDelta = Map[j][i] - Map[j-1][i];
                        //если текущая разность больше дельты, то запоминаем у-координату
                        if( ( currDelta >= 0 ? currDelta : currDelta*-1 ) > delta){
                                yCoordinates[i] = j-1;
                                break;
                        }
                }
        }
        return yCoordinates;
}

__global__ void SomeKernel(int* res, int* data, int col, int row,int y, int step)
{
   unsigned int threadId = blockIdx.x * blockDim.x + threadIdx.x;
        //Считаем идентификатор текущего потока
   int currDelta = 0;
   for (int i=step*threadId; (i<(threadId+1)*step) && (i < col); i++) //Работа со столбцами по потокам
   {
           for (int j = y; j > 0; j--) //Здесь работа со строками
           {
                        currDelta = data[i + j*row] - data[i + (j-1)*row];
                        //если текущая разность больше дельты, то запоминаем у-координату
                        if( ( currDelta >= 0 ? currDelta : currDelta*-1 ) > 10){
                                res[i] = j-1;
                                break;
                        }
           }
   }
}

//int argc, char* argv[]
int main(int argc, char* argv[]){
        map<int,float> Results;

        int numbOfBlock = 1;
        int numbOfThread = 1;
        for (int i = 0; i < columns; i++ )
        {
			if (i&1)
				numbOfThread++;
			else
				numbOfBlock++;
                //for(int numbOfThread = 1; numbOfThread <= columns; numbOfThread++){
                //if(columns % numbOfBlock == 0){
                        //numbOfThread = 1;
        //if (argc > 1)
        //      numbOfBlock = atoi(argv[1]);
        //else
        //      numbOfBlock = 1;
        //if (argc > 2)
        //      numbOfThread = atoi(argv[2]);
        //else
        //      numbOfThread = 1;
        //левая и правая границы высот для генерации
        const int r_left = -20, r_right = 20;
        //Координаты робота на карте
        //int x = rows - 1;
        int y = columns - 1;

        //Карта высот
        int **Map = new int* [rows];
    int* resH = (int*)malloc(rows*columns * sizeof(int));
        for (int i=0; i<columns; i++)
                resH[i] = 0;

        //Заполнение карты случайыми высотами
        for(int i = 0; i < rows; i++){
                Map[i] = new int [columns];

                for(int j = 0; j < columns; j++){
                        //if(j!=0)
                                Map[i][j] = rand()%(r_left - r_right) + r_left;
                        //else
                                //Map[i][j] = 20;
                }
        }
        //Помещаем двумерный массив высот в одномерный
        int* dataH = (int*)malloc(columns * rows * sizeof(int));
   for (int i=0; i<columns; i++)
           for (int j=0; j<rows; j++)
                        dataH[columns*i + j] = Map[i][j];





cudaEvent_t start, stopCopyTo, stopWork, stopCopyFrom;
cudaEventCreate(&start);
cudaEventCreate(&stopCopyTo);
cudaEventCreate(&stopWork);
cudaEventCreate(&stopCopyFrom);





   int* dataDevice;
   int* resDevice;
//Выделяем память на GPU под созданный массив
   cudaMalloc((void**)&dataDevice, (rows * columns) * sizeof(int));
   cudaMalloc((void**)&resDevice, (columns) * sizeof(int));
// Копирование исходных данных в GPU для обработки


cudaEventRecord(start);
   cudaMemcpy(dataDevice, dataH, (rows * columns) * sizeof(int), cudaMemcpyHostToDevice);
   cudaMemcpy(resDevice, resH, (columns)*sizeof(int), cudaMemcpyHostToDevice);

   dim3 threads = dim3(numbOfThread);
   dim3 blocks = dim3(numbOfBlock);

 cudaEventRecord(stopCopyTo);

           SomeKernel<<<blocks, threads>>>( resDevice,
                                                                                dataDevice,
                                                                                columns,
                                                                                rows,
                                                                                y,
                                        (rows * columns)/(numbOfBlock*numbOfThread));


cudaEventRecord(stopWork);

cudaMemcpy(dataH, dataDevice, (rows * columns) * sizeof(int), cudaMemcpyDeviceToHost);
cudaMemcpy(resH, resDevice, (columns) * sizeof(int), cudaMemcpyDeviceToHost);

cudaEventRecord(stopCopyFrom);
cout << "Result vector:  ";
        for (int i=0; i<5; i++)
        {
                cout << resH[i] << " ";
        }

      cout<<'\t';


        for(int i = 0; i < columns; i++){
                delete[] Map[i];
        }

float t1,t2,t3;
cudaEventElapsedTime(&t1, start, stopCopyTo);
cudaEventElapsedTime(&t2, stopCopyTo, stopWork);
cudaEventElapsedTime(&t3, stopWork, stopCopyFrom);

        //cout<<"Threads: "<< numbOfBlock*numbOfThread <<"\tTime: "<<t2<<endl;
        Results.insert(pair<int,float>(numbOfBlock*numbOfThread,t2));
   
}
map<int,float>::iterator it;
ofstream fout("tt1.txt");
  for (it = Results.begin(); it != Results.end(); ++it)///вывод на экран
  {
     fout << it->first << ' ' << it->second << endl;
  }
  fout.close();
//cout << "Количество точек: \t\t" << columns*rows << endl;
//cout << "Количество потоков: \t\t" << numbOfBlock*numbOfThread << endl;
//cout << "Время копирования на GPU: \t" << t1 << endl;
//cout << "Время выполенния: \t\t" << t2 << endl;
//cout << "Время копирования с GPU: \t"  << t3 << endl;

        return 0;
}

