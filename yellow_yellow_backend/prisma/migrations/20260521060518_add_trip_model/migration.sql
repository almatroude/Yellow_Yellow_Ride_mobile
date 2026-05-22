/*
  Warnings:

  - You are about to drop the column `pickupLocation` on the `Trip` table. All the data in the column will be lost.
  - Added the required column `destinationLatitude` to the `Trip` table without a default value. This is not possible if the table is not empty.
  - Added the required column `destinationLongitude` to the `Trip` table without a default value. This is not possible if the table is not empty.
  - Added the required column `pickupLatitude` to the `Trip` table without a default value. This is not possible if the table is not empty.
  - Added the required column `pickupLongitude` to the `Trip` table without a default value. This is not possible if the table is not empty.
  - Added the required column `price` to the `Trip` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updatedAt` to the `Trip` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "TripStatus" AS ENUM ('PENDING', 'ACCEPTED', 'ON_ROUTE', 'COMPLETED', 'CANCELLED');

-- AlterTable
ALTER TABLE "Trip" DROP COLUMN "pickupLocation",
ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "destinationLatitude" DOUBLE PRECISION NOT NULL,
ADD COLUMN     "destinationLongitude" DOUBLE PRECISION NOT NULL,
ADD COLUMN     "pickupLatitude" DOUBLE PRECISION NOT NULL,
ADD COLUMN     "pickupLongitude" DOUBLE PRECISION NOT NULL,
ADD COLUMN     "price" DOUBLE PRECISION NOT NULL,
ADD COLUMN     "status" "TripStatus" NOT NULL DEFAULT 'PENDING',
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL;
